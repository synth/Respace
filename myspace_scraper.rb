gem 'mechanize'
require 'mechanize'


class MyspaceScraper
  attr_accessor :agent, :user, :filelist

  def initialize(_user)

    self.agent = WWW::Mechanize.new
    self.user = _user
    return self
  end

  def save_pics(agnt, album, pic_set)
    dir = "#{self.user}/#{album}"
    FileUtils.mkdir_p dir
    FileUtils.rm Dir.glob(dir+"/*")

    self.filelist ||= {}
    self.filelist[album] ||= []

    pic_set.each_with_index { |pic, index| 
      small_img_url = pic.attributes['src'].value
      img_url = small_img_url.gsub('/m_','/l_')
      puts "Saving photo #{img_url}"
      full_filename = "#{dir}/image#{index}_#{File.basename img_url}"
      agnt.get(img_url).save_as(full_filename)
      self.filelist[album] << full_filename
    }
  end

  def begin
    self.agent.get("http://www.myspace.com/"+self.user)
    pics_link = agent.page.search('#ctl00_cpMain_ctl01_UserBasicInformation1_ctrlViewMorePics')[0].attributes['href'].value
    self.agent.get(pics_link)
    #we may get redirected to a listing of albums
    if self.agent.page.search(".viewGallery").empty?
      album_set = self.agent.page.search("ul.albums li a.title")
      album_set.each do |album|
        album_url = album.attributes['href'].value
        album_title = album.children[0].text
        self.agent.get(album_url)
        pics = self.agent.page.search("#photo_list .photoItem .photoLink img")
        save_pics(agent, album_title, pics)
      end
    else
      pics = agent.page.search("#photo_list .photoItem .photoLink img")
      save_pics(agent, 'My Photos', pics)
    end
    
  end
end

