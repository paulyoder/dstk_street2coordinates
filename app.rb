require 'sinatra'
require 'json'

# A horrible hack to work around my problems getting the Geocoder to install as a gem
$LOAD_PATH.unshift '../geocoder/lib'
require 'geocoder/us/database'
$geocoder_db = Geocoder::US::Database.new '../geocoder/data/geocode.db', {:debug => false}

class GeocodeApp < Sinatra::Base
  get '/street2coordinates/:address' do
    content_type :json
    location = $geocoder_db.geocode params[:address]
    response = {}
    if location && location.length == 1
      response[params[:address]] =  {
        longitude:  location[0][:lon],
        latitude:   location[0][:lat],
        confidence: location[0][:score]
      }
    end
    response.to_json
  end
end
