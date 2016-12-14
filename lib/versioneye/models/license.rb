class License < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  require 'versioneye/models/traits/license_normalizer'
  include VersionEye::LicenseNormalizer

  # This license belongs to the product with this attributes
  field :language     , type: String
  field :prod_key     , type: String
  field :version      , type: String

  field :name           , type: String # For example MIT
  field :url            , type: String # URL to the license text
  field :comments       , type: String # Maven specific
  field :distributions  , type: String # Maven specific
  field :spdx_id        , type: String # For example AGPL-1.0. See http://spdx.org/licenses/
  field :source         , type: String # Where it was crawled

  # TODO This is causing a too large index. For Python some names are containnign the license text. This need to be fixest! See -> License.where(:name => /\n/).count
  # index({ language: 1, prod_key: 1, version: 1, name: 1 }, { name: "language_prod_key_version_name_index", background: true })
  index({ language: 1, prod_key: 1, version: 1 },          { name: "language_prod_key_version_index"     , background: true })
  index({ language: 1, prod_key: 1},                       { name: "language_prod_key_index"             , background: true })

  validates_presence_of :language, :message => 'language is mandatory!'
  validates_presence_of :prod_key, :message => 'prod_key is mandatory!'
  validates_presence_of :name, :message => 'name is mandatory!'

  def product
    Product.fetch_product(self.language, self.prod_key)
  end

  def self.for_product( product, ignore_version = false )
    licenses = []
    if ignore_version
      licenses = License.where(:language => product.language, :prod_key => product.prod_key)
    else
      licenses = License.where(:language => product.language, :prod_key => product.prod_key, :version => product.version)
      if licenses.empty? && product.version.to_s.scan(/\./).count == 1
        licenses = License.where(:language => product.language, :prod_key => product.prod_key, :version => "#{product.version}.0")
      end
    end
    licenses
  end

  # Returns the licenses with nil version!
  def self.for_product_global product
    return License.where(:language => product.language, :prod_key => product.prod_key, :version => nil)
  end

  def self.find_or_create language, prod_key, version, name, url = nil, comments = nil, distributions = nil
    license = License.where(:language => language, :prod_key => prod_key, :version => version, :name => name).first
    return license if license

    license = License.new({ :language => language, :prod_key => prod_key, :version => version, :name => name, :url => url, :comments => comments, :distributions => distributions })
    if license.save
      log.info "new license (#{name}) for #{language}:#{prod_key}:#{version}"
    else
      log.error "Can't save license (#{name}) for #{language}:#{prod_key}:#{version} because #{license.errors.full_messages.to_json}"
    end
    license
  end

  def to_s
    if url
      return "[License for (#{language}/#{prod_key}/#{version}) : #{name}/#{url}]"
    else
      return "[License for (#{language}/#{prod_key}/#{version}) : #{name}]"
    end
  end

end
