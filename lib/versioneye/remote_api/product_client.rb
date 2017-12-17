class ProductClient < CommonClient


  A_API_ENDPOINT_PRODUCT = '/products'


  def self.show language, prod_key, version = nil
    return nil if language.to_s.empty? || prod_key.to_s.empty?

    env     = Settings.instance.environment
    api_key = GlobalSetting.get env, 'api_key'
    encoded_language = encod_language language
    encoded_prod_key = encode prod_key
    url = "#{get_api_url}#{A_API_VERSION}#{A_API_ENDPOINT_PRODUCT}/#{encoded_language}/#{encoded_prod_key}"
    if version
      url += "?prod_version=#{version}"
    end
    if version && !api_key.to_s.empty?
      url = "#{url}&api_key=#{api_key}"
    end
    if version.to_s.empty? && !api_key.to_s.empty?
      url = "#{url}?api_key=#{api_key}"
    end
    json = fetch_json url
  end


  def self.versions language, prod_key
    return nil if language.to_s.empty? || prod_key.to_s.empty?

    env     = Settings.instance.environment
    api_key = GlobalSetting.get env, 'api_key'
    encoded_language = encod_language language
    encoded_prod_key = encode prod_key
    url = "#{get_api_url}#{A_API_VERSION}#{A_API_ENDPOINT_PRODUCT}/#{encoded_language}/#{encoded_prod_key}/versions"
    if !api_key.to_s.empty?
      url = "#{url}?api_key=#{api_key}"
    end
    json = fetch_json url
  end


end
