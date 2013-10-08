module Petfinder

  class Client
    include HTTParty
    format :xml
    base_uri "http://api.petfinder.com"

    def initialize(api_key = Petfinder.api_key, api_secret = Petfinder.api_secret)
      @api_key, @api_secret = api_key, api_secret
      raise "API key is required" unless @api_key

      self.class.default_params :key => api_key
    end

    # Valid animal types: barnyard, bird, cat, dog, horse, pig, reptile, smallfurry
    def breeds(animal_type)
      response = perform_get("/breed.list", :query => {:animal => animal_type})
      Breeds.parse(response, :single => true).breeds
    end

    def pet(id)
      response = perform_get("/pet.get", :query => {:id => id})
      Pet.parse(response, :single => true)
    end

    # Options available: animal, breed, size, sex, location, shelterid
    def random_pet(options = {})
      query = options.merge(:output => 'full')
      response = perform_get("/pet.getRandom", :query => query)
      Pet.parse(response, :single => true)
    end

    # Options available: breed, size, sex, age, offset, count
    def find_pets(animal_type, location, options = {})
      query = options.merge(:animal => animal_type, :location => location)
      response = perform_get("/pet.find", :query => query)
      Pet.parse(response)
    end

    def shelter(id)
      response = perform_get("/shelter.get", :query => {:id => id})
      Shelter.parse(response, :single => true)
    end

    # Options available: name, offset, count
    def find_shelters(location, options = {})
      query = options.merge(:location => location)
      response = perform_get("/shelter.find", :query => query)
      Shelter.parse(response)
    end

    # Options available: offset, count
    def find_shelters_by_breed(animal_type, breed, options = {})
      query = options.merge(:animal => animal_type, :breed => breed)
      response = perform_get("/shelter.listByBreed", :query => query)
      Shelter.parse(response)
    end

    # Options available: status, offset, count
    def shelter_pets(id, options = {})
      query = options.merge(:id => id)
      response = perform_get("/shelter.getPets", :query => query)
      Pet.parse(response)
    end

    def token
      response = perform_get("/auth.getToken", :query => {:sig => digest_key_and_secret})
      Auth.parse(response, :single => true).token
    end

    private

    def digest_key_and_secret
      raise "API secret is required" unless @api_secret
      Digest::MD5.hexdigest(@api_secret + "key=#{@api_key}")
    end

    def digest_params(params = {})
      to_digest = Hash[params.sort].collect{|k,v| "#{k}=#{v}"}.unshift(@api_secret + "key=#{@api_key}").join("&")
      Digest::MD5.hexdigest(to_digest)
    end

    def perform_get(uri, options = {})
      options[:query][:key] = @api_key
      response = self.class.get(uri, options)
      if(raise_errors(response) == 300)
        puts "Unauthorized. Re-attempting with auth."
        options[:query].delete(:key)
        params = options[:query].merge({token: token})
        perform_get(uri, {:query => params.merge({:sig => digest_params(params)})}  )
      end
      response.body
    end

    def raise_errors(response)
      if response.code.to_i == 200
        status = response['petfinder']['header']['status']
        if status['code'].to_i == 300 #unauthorized. re-attempt
          return 300 #This is SPaRtAAAA!
        elsif status['code'].to_i != 100
          raise PetfinderError.new("(#{status['code']}) #{status['message']}")
        end
      else
        raise RuntimeError.new("Invalid response from server: #{response.code}")
      end
    end

  end

end
