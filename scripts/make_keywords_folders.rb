#!/usr/bin/env ruby

###########
#
# For each row, create a directory ('folder' column) and keywords file from the
# list in the 'Facets' column. The 'Facets' column is retained from the source
# spreadsheet that listed the Penn in Hand facets for each manuscript.
#
#     BibID,Shelfmark,Title,Full Coverage?,Facets,,folder
#     9968529323503681,CAJS Rar Ms 125,[al-Aḥādīth = Hadiths].,,"16th century, Paper, Fragment, Arabic, Islamic, Hadith",,cajs_rarms125
#     9968529583503681,CAJS Rar Ms 126,Kitāb al-Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá / ʻIyāḍ ibn Mūsa. Shifā bi-taʻrīf ḥuqūq al-Muṣṭafá,,"15th century, Arabic, Hadith, Islamic, Paper",,cajs_rarms126
#     9924282513503681,CAJS Rar Ms 13,"Bible. Joshua IV, 18-VIII, 6. [Fragment of Joshua, chapters IV, 18-VIII, 6.].",,"13th century, 14th century, Jewish, Damage",,cajs_rarms13
#     9968530023503681,CAJS Rar Ms 132,[Islamic prayers].,,"16th century, Diagram, Document, Arabic, Islamic",,cajs_rarms132
#     9944235503503681,CAJS Rar Ms 137,"Kitāb Rawḍ al-rayāḥīn fī ḥikāyāt al-ṣāliḥīn, 1402. Rawḍ al-rayāḥīn fī ḥikāyāt al-ṣāliḥīn",N,"15th century, Paper, Arabic, Literature -- Prose, Biography",,cajs_rarms137
#     9968530723503681,CAJS Rar Ms 142,Muntahá al-irādāt fī jamʻ al-Muqniʻ maʻa al-tanqīḥ wa-ziyādāt / al-Ḥanbalī.,,"16th century, Arabic, Islamic, Paper, Legal",,cajs_rarms142
#     9968531063503681,CAJS Rar Ms 143,[Hidāyah]. Hidāyah,,"16th century, Paper, Commentary, Islamic, Arabic, Legal",,cajs_rarms143
#     9968531323503681,CAJS Rar Ms 147,[Commentary on Manār al-anwār fī al-uṣūl].,,"16th century, Commentary, Legal, Paper, Islamic",,cajs_rarms147
#     9968531423503681,CAJS Rar Ms 159,[Mughnī al-labīb ʻan kutub al-aʻārīb]. Mughnī al-labīb ʻan kutub al-aʻārīb,,"16th century, Arabic, Islamic, Grammar, Paper",,cajs_rarms159

require 'csv'
require 'yaml'

source      = File.expand_path '../../data/folders_keywords.csv', __FILE__
DATA_FOLDER = File.expand_path '../../mss_with_keywords', __FILE__

CSV.foreach source, headers: true do |row|
  folder   = row['folder']
  keywords = row['Facets']
  dir      = File.join DATA_FOLDER, folder
  Dir.mkdir dir unless File.exist? dir
  File.open File.join(dir, 'keywords.txt'), 'w+' do |f|
    f.puts keywords.split(/\s*,\s*/).map(&:strip)
  end
end
