class MeClient < CommonClient


  A_API_ENDPOINT_PRODUCT = '/me'


  def self.show api_key
    return nil if api_key.to_s.empty?

    url = "#{get_api_url}#{A_API_VERSION}#{A_API_ENDPOINT_PRODUCT}?api_key=#{api_key}"
    json = fetch_json url
  end


end
