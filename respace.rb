require 'mini_fb'
require 'camping/session'
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
      attr_accessor :access_token, :album, :album_set, :created_new_album
      def initialize(token, destination_album)
	self.access_token = token
      end

     def album
        self.album ||= PhotoImporter.find_or_create_album(destrination_album)
     end

     def album_set
        self.album_set ||= PhotoImporter.get_albums
     end

     def self.find_or_create_album(album_name)

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
          self.album = MiniFb.get(self.access_token, r.id)
        end
    	self.album.aid = CGI::parse(@album.link.to_s.gsub(/.*\?/, ''))["aid"]
	return self.album
      end

      def self.get_albums(user='me')
        album_set = MiniFB.get(self.access_token, "#{user}/albums").data
      end

      def import_photos
        r = nil
        begin
           file = File.new("rubber-ducky.jpg", 'rb')
	   r = MiniFB.post(self.access_token, "#{self.album.id}/photos", :file=> file)
        rescue MiniFB::FaceBookError => e
          puts "caught exception: #{e.inspect}"
          @error = e 
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
    form :action => "photos" ,:method => "post" do |f|
      label "Enter the url to your public profile"
      input :type => "text", :name => "url"
      input :type => "submit", :value => "Submit" 
    end
  end
  def loaded
    h3 "Photos imported from url : #{@url}"
    a "Back", :href => "session"
  end
end
