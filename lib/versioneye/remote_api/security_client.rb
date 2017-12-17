class SecurityClient < CommonClient


  A_API_ENDPOINT_SECURITY = '/security'


  def self.index language, prod_key = nil
    return nil if language.to_s.empty?

    env     = Settings.instance.environment
    api_key = GlobalSetting.get env, 'api_key'
    encoded_language = encod_language language
    url = "#{get_api_url}#{A_API_VERSION}#{A_API_ENDPOINT_SECURITY}?language=#{encoded_language}"
    if !prod_key.to_s.empty?
      encoded_prod_key = encode prod_key
      url = "#{url}&prod_key=#{encoded_prod_key}"
    end
    if !api_key.to_s.empty?
      url = "#{url}&api_key=#{api_key}"
    end
    json = fetch_json url
  end


end
