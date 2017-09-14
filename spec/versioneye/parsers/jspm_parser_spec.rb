require 'spec_helper'

describe PackageParser do
  let(:parser){ PackageParser.new }
  let(:test_content){ File.read('spec/fixtures/files/npm/package_jspm.json') }

  let(:react_dom){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'react-dom',
      name: 'react-dom',
      version: '0.14.9'
    )
  }

  let(:plugin_babel){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'plugin-babel',
      name: 'plugin-babel',
      version: '0.1.0'
    )
  }

  let(:core_js){
    Product.new(
      language: Product::A_LANGUAGE_NODEJS,
      prod_type: Project::A_TYPE_NPM,
      prod_key: 'core-js',
      name: 'core-js',
      version: '1.3.0'
    )
  }

  context "parse_content" do
    before do
      react_dom.versions << Version.new(version: '0.14.6')
      react_dom.versions << Version.new(version: '0.14.9')
      react_dom.save

      plugin_babel.versions << Version.new(version: '0.0.5')
      plugin_babel.versions << Version.new(version: '0.0.8')
      plugin_babel.versions << Version.new(version: '0.1.0')
      plugin_babel.save

      core_js.versions << Version.new(version: '1.2.0')
      core_js.versions << Version.new(version: '1.2.5')
      core_js.versions << Version.new(version: '1.3.0')
      core_js.save
    end

    it "parses correctly test file" do
      proj = parser.parse_content test_content
      expect(proj).not_to be_nil
      expect(proj.dependencies.size).to eq(5)

      dep1 = proj.dependencies[0]
      expect(dep1[:name]).to eq(react_dom[:name])
      expect(dep1[:prod_key]).to eq(react_dom[:prod_key])
      expect(dep1[:language]).to eq(react_dom[:language])
      expect(dep1[:scope]).to eq("jspm_#{Dependency::A_SCOPE_COMPILE}")
      expect(dep1[:version_requested]).to eq('0.14.9')
      expect(dep1[:version_label]).to eq('^0.14.6')
      expect(dep1[:comperator]).to eq('^')
      expect(dep1[:outdated]).to be_falsey

      dep2 = proj.dependencies[1]
      expect(dep2[:name]).to eq("typhonjs-core-utils")
      expect(dep2[:prod_key]).to be_nil
      expect(dep2[:ext_link]).to eq("https://github.com/typhonjs-common/typhonjs-core-utils")
      expect(dep2[:language]).to eq( Product::A_LANGUAGE_NODEJS )
      expect(dep2[:scope]).to eq( "jspm_#{Dependency::A_SCOPE_COMPILE}" )
      expect(dep2[:version_requested]).to eq('github@master')
      expect(dep2[:version_label]).to eq('github@master')
      expect(dep2[:comperator]).to eq('=')
      expect(dep2[:outdated]).to be_falsey

      dep2 = proj.dependencies[2]
      expect(dep2[:name]).to eq(plugin_babel[:name])
      expect(dep2[:prod_key]).to eq(plugin_babel[:prod_key])
      expect(dep2[:language]).to eq(plugin_babel[:language])
      expect(dep2[:scope]).to eq("jspm_#{Dependency::A_SCOPE_DEVELOPMENT}")
      expect(dep2[:version_requested]).to eq('0.0.5')
      expect(dep2[:version_label]).to eq('^0.0.5')
      expect(dep2[:comperator]).to eq('^')
      expect(dep2[:outdated]).to be_truthy

      dep3 = proj.dependencies[3]
      expect(dep3[:name]).to eq('systemjs-hot-reloader')
      expect(dep3[:prod_key]).to be_nil
      expect(dep3[:language]).to eq(plugin_babel[:language])
      expect(dep3[:scope]).to eq("jspm_#{Dependency::A_SCOPE_DEVELOPMENT}")
      expect(dep3[:version_requested]).to eq('github@^0.5.1')
      expect(dep3[:version_label]).to eq('github@^0.5.1')
      expect(dep3[:comperator]).to eq('=')
      expect(dep3[:outdated]).to be_falsey

      dep4 = proj.dependencies[4]
      expect(dep4[:name]).to eq(core_js[:name])
      expect(dep4[:prod_key]).to eq(core_js[:prod_key])
      expect(dep4[:language]).to eq(core_js[:language])
      expect(dep4[:scope]).to eq("jspm_#{Dependency::A_SCOPE_OPTIONAL}")
      expect(dep4[:version_requested]).to eq('1.3.0')
      expect(dep4[:version_label]).to eq('^1.2.0')
      expect(dep4[:comperator]).to eq('^')
      expect(dep4[:outdated]).to be_falsey
    end
  end

end
