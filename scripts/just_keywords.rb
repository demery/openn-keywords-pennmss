#!/usr/bin/env ruby

################################################################################
# Read the source OPenn keywords CSV for Penn MSS. Select rows with keywords
# to use on OPenn. Figure out the shelf mark (from bibid) and generate folder
# name, replacing the shelf mark if different and adding folder name column.
#
# Input CSV has this format:
#
#   BibID,Shelfmark,Title,Full Coverage?,Facets,
#   9968529323503681,CAJS Rar Ms 125,[al-Aḥādīth = Hadiths].,,"Arabic, 16th century, 1515, Detached leaves Manuscripts, Arabic - 16th century Manuscripts, Renaissance, Hadith Qalqashandī, Ibrāhīm ibn ʻAlī, -1516 or 1517, Qalqashandī, Ibrāhīm ibn ʻAlī, -1516 or 1517, Paper, , 1515.",
#   9968529323503681,CAJS Rar Ms 125,[al-Aḥādīth = Hadiths].,,"16th century, Paper, Fragment, Arabic, Islamic, Hadith",
#   9968529583503681,CAJS Rar Ms 126,Kitāb al-Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá / ʻIyāḍ ibn Mūsa. Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá,,"Arabic, 15th century, 1428, Codices Manuscripts, Arabic - 15th century Manuscripts, Renaissance, Hadith Islam Muḥammad, Prophet, -632 Religious life, ʻIyāḍ ibn Mūsá, 1083-1149, Paper, , 1428.",
#   9968529583503681,CAJS Rar Ms 126,Kitāb al-Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá / ʻIyāḍ ibn Mūsa. Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá,,"15th century, Arabic, Hadith, Islamic, Paper",
#   ...
#   9949470363503681,Ms. Coll. 764,"Antonio Cocchi Donati will, 1424.",N,"Latin, 15th century, 1424, Legal documents Manuscripts, Latin - 15th century Manuscripts, Renaissance Notarial documents Wills, Angeli, Niccolò Antoni, Jacopo Borghi, Pietro Cocchi Donati, Antonio Cocchi Donati, Piera, Florence (Italy) Italy Prato (Italy), Parchment, , ",
#   9949470363503681,Ms. Coll. 764,"Antonio Cocchi Donati will, 1424.",N,"15th century, Legal, Italian, Document",
#   ...
#
# Each manuscript has two rows. The first contains Penn in Hand facets. The
# second has the OPenn keywords. It's the second we want.
#
# The output CSV looks like this:
#
#   BibID,Shelfmark,Title,Full Coverage?,Facets,,folder
#   9968529323503681,CAJS Rar Ms 125,[al-Aḥādīth = Hadiths].,,"16th century, Paper, Fragment, Arabic, Islamic, Hadith",,cajs_rarms125
#   9968529583503681,CAJS Rar Ms 126,Kitāb al-Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá / ʻIyāḍ ibn Mūsa. Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá,,"15th century, Arabic, Hadith, Islamic, Paper",,cajs_rarms126
#   ...
#   9949470363503681,Ms. Coll. 764 Item 124,"Antonio Cocchi Donati will, 1424.",N,"15th century, Legal, Italian, Document",,mscoll764_item124
#   ...
#
################################################################################

require 'csv'
require 'open-uri'
require 'nokogiri'
require 'yaml'
require 'set'

STRIP_SHELFMARK_RE   = %r{\.}
UNDERSCORE_RE        = %r{[-\s/]+}
MS_CODEX_RE          = %r{^ms\.?\s*codex\s*}i
MS_COLL_RE           = %r{^ms\.?\s*coll\.\s*}i
MISC_MSS_RE          = %r{^misc\s*mss\s*}i
LJS_RE               = %r{^ljs\s*}i
CAJS_RE              = %r{^cajs\s*rar\s*ms\s+}i
MS_OVERSIZE_RE       = %r{^ms\.?\s*oversize\s*}i
DIACRITICS_RE        = %r{[^\w\d]}
FOLDER_RE            = %r{folders?\s*}i
ITEM_RE              = %r{item\s*}i
MS_ROLL_RE           = %r{^.*ms\.?\s*roll\s*}i
OVERSIZE_MS_CODEX_RE = %r{^oversize ms\.?\s*codex\s*}i

SHELFMARK_CACHE_FILE = File.expand_path '../shelfmark_cache.yml', __FILE__
FOLDER_NAMES         = {}
BIBIDS               = Set.new
BIBIDS_TO_SKIP       = []
# BIBIDS_TO_SKIP       = %w{ 9915804523503681 9915804533503681 9915804543503681
#                            9915804553503681 9915804563503681 9944799583503681
#                            9944799623503681 9915806223503681 9915806233503681
#                            9915806243503681 9915806253503681 9915806263503681
#                            9915806273503681 9915806283503681 9931755613503681
#                            9935560683503681 9935561053503681 }.freeze

##
# @return [Hash]
def prep_cache
  return {} unless File.exist? SHELFMARK_CACHE_FILE

  YAML::load_file SHELFMARK_CACHE_FILE
end
SHELFMARK_CACHE = prep_cache

##
# @param hash [Hash]
def write_cache hash
  File.open SHELFMARK_CACHE_FILE, 'w+' do |f|
    f.puts YAML::dump hash
  end
end

##
# Apply string substitutions that apply to all folder names.
#
# @param folder [String]
def normalize_folder folder
  folder.to_s.downcase.strip.sub(FOLDER_RE, 'f').sub(ITEM_RE, 'item').gsub(STRIP_SHELFMARK_RE, '').gsub(UNDERSCORE_RE, '_').unicode_normalize(:nfd).gsub(DIACRITICS_RE, '')
end

def check_folder_name folder, bibid
  if FOLDER_NAMES.include? folder
    STDERR.puts "WARNING: duplicate folder: '#{folder}'; bibid: '#{bibid}': previous: #{FOLDER_NAMES[folder].join ', '}"
  end

  (FOLDER_NAMES[folder] ||= []) << bibid
end

def check_bibid bibid
  if BIBIDS.include? bibid
    STDERR.puts "WARNING: duplicate bibid: '#{bibid}'"
  else
    BIBIDS << bibid
  end
end

# "CAJS Rar Ms",
# "Folio GrC St812 Ef512g",
# "Folio Inc P-",
# "LJS",
# "Misc Mss",
# "Misc Mss (Large) Box 1 Folder",
# "Misc Mss (Large) Box 2 Folder",
# "Misc Mss (Large) Box 3 Folder",
# "Misc Mss Box 3 Folder",
# "Misc. Mss.",
# "MS 56, Codex 001.",
# "Ms. Codex",
# "Ms. Coll.",
# "Ms. Oversize",
# "Ms. Roll",
# "Ms.Codex",
# "N6923.B9 G5",
# "Penn Museum NEP",
# "Yusufağa Kütüphanesi 5544/",
# "Yusufağa Kütüphanesi",
#
# @param shelfmark [String]
# @param bibid [Integer]
# @param last_used_shelfmark [String]
def folder_name shelfmark, bibid, last_used_shelfmark
  prepped = shelfmark.downcase.strip
  folder = case prepped
           when MS_OVERSIZE_RE
             normalize_folder prepped.sub(MS_OVERSIZE_RE, 'msoversize')
           when MS_COLL_RE
             normalize_folder prepped.sub(MS_COLL_RE, 'mscoll')
           when MISC_MSS_RE
             normalize_folder prepped.sub(MISC_MSS_RE, 'miscmss')
           when LJS_RE
             normalize_folder prepped.sub(LJS_RE, 'ljs')
           when OVERSIZE_MS_CODEX_RE
             normalize_folder prepped.sub(OVERSIZE_MS_CODEX_RE, 'oversize_mscodex')
           when MS_CODEX_RE
             normalize_folder prepped.sub(MS_CODEX_RE, 'mscodex')
           when CAJS_RE
             normalize_folder prepped.sub(CAJS_RE, 'cajs_rarms')
           when MS_ROLL_RE
             normalize_folder prepped.sub(MS_ROLL_RE, 'msroll')
           else
             normalize_folder prepped
           end

  check_folder_name folder, bibid
  check_bibid bibid

  return folder unless shelfmark == last_used_shelfmark
  "#{folder}_#{bibid}"
end

MDPROC_FORMAT_STRING = 'http://mdproc.library.upenn.edu:9292/records/%s/create?format=marc21'
def full_shelfmark shelfmark, bibid
  return SHELFMARK_CACHE[bibid] if SHELFMARK_CACHE.include? bibid

  begin
    data = Nokogiri::XML open(sprintf MDPROC_FORMAT_STRING, bibid.to_s)
  rescue Exception => e
    STDERR.puts "ERROR processing record with bibid: '#{bibid}'"
    raise e
  end
  shelfmark = data.xpath "//marc:call_number/text()"
  item = data.xpath "//marc:datafield[@tag=773]/marc:subfield[@code='g']/text()"
  SHELFMARK_CACHE[bibid] = "#{shelfmark.text} #{item.text}".strip
end

file = ARGV.shift

headers = CSV.open(file, 'r') { |csv| csv.first }
headers << 'folder'
prev_bibid = nil
last_used_shelfmark = nil

CSV do |new_csv|
  new_csv << headers
  CSV.foreach file, headers: true do |row|
    bibid = row['BibID']
    next if BIBIDS_TO_SKIP.include? bibid
    next if bibid.nil?
    next if bibid.to_s.strip.empty?
    # if this is the second time we see the bibid, then this is the row we want
    if prev_bibid == bibid
      shelfmark = full_shelfmark row['Shelfmark'], bibid
      row['Shelfmark'] = shelfmark unless row['Shelfmark'] == shelfmark
      row['folder'] = folder_name shelfmark, bibid, last_used_shelfmark

      last_used_shelfmark = shelfmark
      new_csv << row
    end
    prev_bibid = bibid
  end
end

write_cache SHELFMARK_CACHE

FOLDER_NAMES.each { |folder,bibids| STDERR.puts bibids.join('|') if bibids.size > 1 }
