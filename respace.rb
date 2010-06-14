require 'mini_fb'
require 'camping/session'
require 'myspace_scraper'
#MiniFB.enable_logging

APP_ID = "100817573303266"
API_KEY = "7d2bef2a91bd86bba1c4c4e0aa522151"
SECRET_KEY = "29025ad019e02a5ec3da7594caf574d8"

#AUTH_REDIRECT = "http://174.143.236.206/session"
AUTH_REDIRECT = "http://apps.facebook.com/respace/session"
CANVAS_URL = "http://apps.facebook.com/respace"
#CANVAS_URL = "http://174.143.236.206"
DEFAULT_ALBUM_NAME = "Imported Photos From Myspace"

Camping.goes :Respace

module Respace
  include Camping::Session
  module Models

    class PhotoImporter
      attr_accessor :access_token, :album, :album_set, :destination_album_name, :created_new_album
      def initialize(token, destination_album)
	self.access_token = token
	self.destination_album_name = destination_album
      end

     def album
        @album ||= self.find_or_create_album(self.destination_album_name)
     end

     def album_set
        @album_set ||= self.get_albums
     end

     def find_or_create_album(album_name)
        found_album = nil
        self.album_set.each do |a|
         found_album = a if album_name == a.name
         break if found_album
        end
      
        if found_album
          self.created_new_album = false
          self.album = found_album
        else
          self.created_new_album = true
          r = MiniFB.post(self.access_token, "me/albums", :name => album_name)
          self.album = MiniFB.get(self.access_token, r.id)
        end
    	self.album.aid = CGI::parse(@album.link.to_s.gsub(/.*\?/, ''))["aid"]
	return self.album
      end

      def get_albums(user='me')
        album_set = MiniFB.get(self.access_token, "#{user}/albums").data
      end

      def import_photos(albums=[])
        r = nil
        albums.each do |album, fileset|
          fileset.each do |f|
          begin
             file = File.new(f, 'rb')
	     r = MiniFB.post(self.access_token, "#{self.album.id}/photos", :file=> file)
          rescue MiniFB::FaceBookError => e
            puts "caught exception: #{e.inspect}"
            @error = e 
          end
          end
        end

      end

    end 
  end 
end

module Respace::Controllers
  class Index 
    def post
      @auth_url = MiniFB.oauth_url(APP_ID, AUTH_REDIRECT, :scope=>MiniFB.scopes.join(","))
      render :auth
    end 
  end
  class Session
    def post 
      unless cookies['access_token']
        @access_token_hash = MiniFB.oauth_access_token(APP_ID, AUTH_REDIRECT, SECRET_KEY, input.code)
        @access_token = @access_token_hash['access_token']
        cookies['access_token'] = @access_token
      else
        @access_token = cookies['access_token']
      end
      @user = MiniFB.get(@access_token, 'me')

      album_name = input.album_name || DEFAULT_ALBUM_NAME
      @importer = PhotoImporter.new(@access_token, album_name)

      render :user_form
    end 
  end 
 class Photos
   def get
     puts "Photos#get"
   end

   def post
     puts "Photos#post"
     puts "params: #{input.inspect}"
     @url = input.url
     @access_token = cookies['access_token']

     album_name = input.album_name || DEFAULT_ALBUM_NAME
     @importer = PhotoImporter.new(@access_token, album_name)
     @myspace_scraper = MyspaceScraper.new("technofile")
     @myspace_scraper.begin

     @importer.import_photos(@myspace_scraper.filelist)
     render :loaded
   end
 end
end

module Respace::Views
  def layout
    self << yield 
  end
  def time
    "Time is now: #{@time.to_s}"
  end 
  def auth
  "<fb:redirect url=\"#{@auth_url}\""
  end
  def session

  end 
  def user_form
    h1 "Respace"
    h2 "This app scrapes all public pictures from a users profile and imports than into facebook"
    hr
    ol do 
    li "I make no claims as to whether this will work for you or not"
    li "If you have problems, try clearing your cookies, and logging back in to fb and trying again"
    li "Myspace does not allow you to export their photos via their api, so just make sure your photos are public and this should work"
    li "You can set the visibility on your myspace photos back to private once they are imported"
    li "Remember to set your privacy settings on these imported photos as well"
    li "Also, if you try this multiple times, you may get duplicate photos"
    li do 
	"If you have problems, contact me through the "  + a( "Respace profile page here", :href => "http://www.facebook.com/apps/application.php?id=100817573303266"  )
    end
    end
    hr
    form :action => "photos" ,:method => "post" do |f|
      label "Enter your username to your public profile http://www.myspace.com/"

      input :type => "text", :name => "url"
      input :type => "submit", :value => "Submit" 

    end
  end
  def loaded
    h3 "Photos imported from url : #{@url}"
    a "Back", :href => "session"
  end
end

