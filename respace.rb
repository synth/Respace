gem 'mechanize'
gem 'facebooker'
require 'mechanize'
require 'facebooker'

agent = WWW::Mechanize.new
FileUtils.mkdir_p 'myspace_photos'

def save_pics(agnt, album, pic_set)
FileUtils.mkdir_p "myspace_photos/#{album}"
pic_set.each_with_index { |pic, index| 
  small_img_url = pic.attributes['src'].value
  img_url = small_img_url.gsub('/m_','/l_')
  puts "Saving photo #{img_url}"
  agnt.get(img_url).save_as("myspace_photos/#{album}/image#{index}_#{File.basename img_url}")
}
end

agent.get("http://myspace.com/technofile")
pics_link = agent.page.search('#ctl00_cpMain_ctl01_UserBasicInformation1_ctrlViewMorePics')[0].attributes['href'].value
agent.get(pics_link)
#we may get redirected to a listing of albums
if agent.page.search(".viewGallery").empty?
album_set = agent.page.search("ul.albums li a.title")
album_set.each do |album|
album_url = album.attributes['href'].value
album_title = album.children[0].text
agent.get(album_url)
pics = agent.page.search("#photo_list .photoItem .photoLink img")
save_pics(agent, album_title, pics)
end
else
pics = agent.page.search("#photo_list .photoItem .photoLink img")
save_pics(agent, 'My Photos', pics)
end
