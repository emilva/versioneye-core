require 'spec_helper'

describe CargoParser do

  let(:parser){ CargoParser.new }
  let(:test_filepath){ 'spec/fixtures/files/cargo/Cargo.toml' }

  let(:product1){
    Product.new(
      language: Product::A_LANGUAGE_RUST,
      prod_type: Project::A_TYPE_CARGO,
      prod_key: 'nanomsg',
      name: 'nanomsg',
      version: '0.6.2'
    )
  }

  let(:dep1){
    Projectdependency.new(
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'libc',
      name: 'libc'
    )
  }

  context "is_semver" do
    it "returns truthy for version without selectors" do
      expect( parser.is_semver('1') ).to be_truthy
      expect( parser.is_semver('1.2')).to be_truthy
      expect( parser.is_semver('1.2.3')).to be_truthy
    end

    it "returns falsey for version with selectors" do
      expect( parser.is_semver('>1')).to be_falsey
      expect( parser.is_semver('*')).to be_falsey
      expect( parser.is_semver('^ 1.0.0')).to be_falsey
    end
  end

  context "tilde_lower_border" do
    it "returns correct lower border" do
      expect( parser.tilde_lower_border('1.2.3')).to eq('1.2.3')
      expect( parser.tilde_lower_border('1.2')).to eq('1.2.0')
      expect( parser.tilde_lower_border('1')).to eq('1.0.0')
    end
  end

  context "tilde_upper_border" do
    it "returns correct upper version" do
      expect( parser.tilde_upper_border('1.2.3')).to eq('1.3.0')
      expect( parser.tilde_upper_border('1.2')).to eq('1.3.0')
      expect( parser.tilde_upper_border('1.0')).to eq('1.1.0')
      expect( parser.tilde_upper_border('1')).to eq('2.0.0')
      expect( parser.tilde_upper_border('0')).to eq('1.0.0')
    end
  end

  context "parse_requested_version" do
    before do
      product1.versions << Version.new(version: '0.6.0')
      product1.versions << Version.new(version: '0.6.2')
      product1.save
    end

    it "uses latest product version if version label is empty" do
      dep = parser.parse_requested_version(nil, dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq(product1[:version])
      expect(dep[:version_label]).to eq('')
      expect(dep[:comperator]).to eq('=')
    end

    it "uses version label when product is nil" do
      dep = parser.parse_requested_version('^0.2', dep1, nil)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('^0.2')
      expect(dep[:version_label]).to eq('^0.2')
      expect(dep[:comperator]).to eq('=')
    end

    it "uses latest product version if version label is *, x, X" do
      dep = parser.parse_requested_version("*", dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq(product1[:version])
      expect(dep[:version_label]).to eq('*')
      expect(dep[:comperator]).to eq('=')
    end

    it "parses correctly `= 0.6.0`" do
      dep = parser.parse_requested_version('= 0.6.0', dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.0')
      expect(dep[:version_label]).to eq('0.6.0')
      expect(dep[:comperator]).to eq('=')
    end

    it "uses the latest version when fixed version doesnt exist" do
      product1.versions.where('version': '0.6.0').delete
      product1.save

      dep = parser.parse_requested_version('= 0.6.0', dep1, product1)
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq(product1[:version])
      expect(dep[:version_label]).to be_nil
      expect(dep[:comperator]).to eq('=')
    end

    it "parses correctly `< 0.6.2`" do
      dep = parser.parse_requested_version('< 0.6.2', dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.0')
      expect(dep[:version_label]).to eq('0.6.2')
      expect(dep[:comperator]).to eq('<')
    end

    it "parses correctly `<= 0.6.2`" do
      product1.versions << Version.new(version: "0.7.0")
      product1.save

      dep = parser.parse_requested_version('<= 0.6.2', dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.2')
      expect(dep[:version_label]).to eq('0.6.2')
      expect(dep[:comperator]).to eq('<=')
    end

    it "parses correctly `>= 0.6.2`" do
      product1.versions << Version.new(version: '0.7.0')
      product1.save

      dep = parser.parse_requested_version('>= 0.6.2', dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.7.0')
      expect(dep[:version_label]).to eq('0.6.2')
      expect(dep[:comperator]).to eq('>=')
    end

    it "parses correctly `> 0.6.2`" do
      product1.versions << Version.new(version: '0.7.0')
      product1.save

      dep = parser.parse_requested_version('> 0.6.2', dep1, product1)

      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.7.0')
      expect(dep[:version_label]).to eq('0.6.2')
      expect(dep[:comperator]).to eq('>')
    end

    it "parses correctly caret selectors" do
      product1.versions << Version.new(version: '0.7.0')
      product1.versions << Version.new(version: '1.0.0')
      product1.save

      dep = parser.parse_requested_version '^0.6', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.2')
      expect(dep[:version_label]).to eq('0.6')
      expect(dep[:comperator]).to eq('^')

      dep = parser.parse_requested_version '^0', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.7.0')
      expect(dep[:version_label]).to eq('0')
      expect(dep[:comperator]).to eq('^')

      #NB! versions without any specifiers are classified as caret selector
      dep = parser.parse_requested_version '0.6', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.2')
      expect(dep[:version_label]).to eq('0.6')
      expect(dep[:comperator]).to eq('^')
    end

    it "parses correctly ^0.3" do
      product1.versions = []
      product1.versions << Version.new(version: '0.2.9')
      product1.versions << Version.new(version: '0.3.1')
      product1.versions << Version.new(version: '0.3.2')
      product1.versions << Version.new(version: '0.3.15')
      product1.versions << Version.new(version: '0.4.0')
      product1[:version] = '0.4.0'
      product1.save

      dep = parser.parse_requested_version '^0.3', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.3.15')
      expect(dep[:version_label]).to eq('0.3')
      expect(dep[:comperator]).to eq('^')
    end

    it "^0.3 shouldnt be outdated when matches range" do
      product1.versions = []
      product1.versions << Version.new(version: '0.2.9')
      product1.versions << Version.new(version: '0.3.1')
      product1.versions << Version.new(version: '0.3.2')
      product1.versions << Version.new(version: '0.3.15')
      product1[:version] = '0.3.15'
      product1.save

      dep = parser.parse_requested_version '^0.3', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.3.15')
      expect(dep[:version_label]).to eq('0.3')
      expect(dep[:comperator]).to eq('^')
      expect(ProjectdependencyService.outdated?(dep)).to be_falsey
    end

    it "parses correctly tilde specifiers" do
      product1.versions << Version.new(version: '0.7.0')
      product1.versions << Version.new(version: '1.0.0')
      product1.save

      dep = parser.parse_requested_version '~0.6', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.2')
      expect(dep[:version_label]).to eq('0.6')
      expect(dep[:comperator]).to eq('~')

      dep = parser.parse_requested_version '~0', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.7.0')
      expect(dep[:version_label]).to eq('0')
      expect(dep[:comperator]).to eq('~')
    end

    it "parses correctly wildcard selectors" do
      product1.versions << Version.new(version: '0.7.0')
      product1.versions << Version.new(version: '1.0.0')
      product1.save

      dep = parser.parse_requested_version '0.6.*', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.2')
      expect(dep[:version_label]).to eq('0.6.*')
      expect(dep[:comperator]).to eq('*')

      dep = parser.parse_requested_version '0.*', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.7.0')
      expect(dep[:version_label]).to eq('0.*')
      expect(dep[:comperator]).to eq('*')

      dep = parser.parse_requested_version '1.*', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('1.0.0')
      expect(dep[:version_label]).to eq('1.*')
      expect(dep[:comperator]).to eq('*')
    end

    it "parses correctly combined range selectors" do
      product1.versions << Version.new(version: '0.7.0')
      product1.versions << Version.new(version: '1.0.0')
      product1.save

      dep = parser.parse_requested_version '>= 0.2, < 0.7', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('0.6.2')
      expect(dep[:version_label]).to eq('>= 0.2, < 0.7')
      expect(dep[:comperator]).to eq('||')
    end

    it "parses correctly git versions" do
      dep = parser.parse_requested_version 'git://github.com/serde/serde', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('GIT')
      expect(dep[:version_label]).to eq('GIT')
      expect(dep[:comperator]).to eq('=')
    end

    it "parses correctly path versions" do
      dep = parser.parse_requested_version 'hello_utils', dep1, product1
      expect(dep).not_to be_nil
      expect(dep[:version_requested]).to eq('PATH')
      expect(dep[:version_label]).to eq('PATH')
      expect(dep[:comperator]).to eq('=')
    end
  end

  let(:product2){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'serde',
      name: 'serde',
      version: '1.0.0'
    )
  }

  let(:product3){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'time',
      name: 'time',
      version: '1.2.4'
    )
  }

  let(:product4){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'rand',
      name: 'rand',
      version: '2.3.0'
    )
  }

  let(:product5){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'hello_utils',
      name: 'hello_utils',
      version: '2.5.2'
    )
  }

  let(:product6){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'www',
      name: 'www',
      version: '2.6.2'
    )
  }

  let(:product7){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'multipart',
      name: 'multipart',
      version: '1.2.0'
    )
  }

  let(:product8){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'tempdir',
      name: 'tempdir',
      version: '0.3'
    )
  }

  let(:product9){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'gcc',
      name: 'gcc',
      version: '0.5'
    )
  }

  let(:product10){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'winhttp',
      name: 'winhttp',
      version: '0.4.0'
    )
  }

  let(:product11){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'mio',
      name: 'mio',
      version: '0.0.1'
    )
  }

  let(:product12){
    Product.new(
      prod_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      prod_key: 'winapi-i686-pc-windows-gnu',
      name: 'winapi-i686-pc-windows-gnu',
      version: '0.3'
    )
  }


  context 'parse_content' do
    before do
      product2.versions << Version.new(version: '1.0.0')
      product2.save

      product3.versions << Version.new(version: '1.2.3')
      product3.save
      product4.save
      product5.save

      product6.versions = []
      product6.versions << Version.new(version: '2.6.2')
      product6.versions << Version.new(version: '0.7.2')
      product6.save

      product7.save

      product8.versions = []
      product8.versions << Version.new(version: '0.3')
      product8.versions << Version.new(version: '0.5')
      product8.save

      product9.versions = []
      product9.versions << Version.new(version: '0.3')
      product9.versions << Version.new(version: '0.9')
      product9.save

      product10.save
      product11.save
      product12.save
    end

    it "parses project file correctly" do
      content = File.read test_filepath
      project = parser.parse_content content
      expect(project.nil?).to be_falsey
      expect(project.projectdependencies.size).to eq(11)

      dep1 = project.dependencies[0]
      expect(dep1[:name]).to eq(product2[:name])
      expect(dep1[:prod_key]).to eq(product2[:prod_key])
      expect(dep1[:language]).to eq(product2[:language])
      expect(dep1[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep1[:version_requested]).to eq('1.0.0')
      expect(dep1[:version_label]).to eq('1.0.0')
      expect(dep1[:comperator]).to eq('^')
      expect(dep1[:outdated]).to be_falsey

      dep2 = project.dependencies[1]
      expect(dep2[:name]).to eq(product3[:name])
      expect(dep2[:prod_key]).to eq(product3[:prod_key])
      expect(dep2[:language]).to eq(product3[:language])
      expect(dep2[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep2[:version_requested]).to eq('1.2.3')
      expect(dep2[:version_label]).to eq('1.2.3')
      expect(dep2[:comperator]).to eq('~')
      expect(dep2[:outdated]).to be_falsey


      dep3 = project.dependencies[2]
      expect(dep3[:name]).to eq(product4[:name])
      expect(dep3[:prod_key]).to eq(product4[:prod_key])
      expect(dep3[:language]).to eq(product4[:language])
      expect(dep3[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep3[:version_requested]).to eq('GIT')
      expect(dep3[:version_label]).to eq('GIT')
      expect(dep3[:comperator]).to eq('=')
      expect(dep3[:outdated]).to be_falsey

      dep4 = project.dependencies[3]
      expect(dep4[:name]).to eq(product5[:name])
      expect(dep4[:prod_key]).to eq(product5[:prod_key])
      expect(dep4[:language]).to eq(product5[:language])
      expect(dep4[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep4[:version_requested]).to eq('PATH')
      expect(dep4[:version_label]).to eq('PATH')
      expect(dep4[:comperator]).to eq('=')
      expect(dep4[:outdated]).to be_falsey

      dep5 = project.dependencies[4]
      expect(dep5[:name]).to eq(product6[:name])
      expect(dep5[:prod_key]).to eq(product6[:prod_key])
      expect(dep5[:language]).to eq(product6[:language])
      expect(dep5[:scope]).to eq(Dependency::A_SCOPE_OPTIONAL)
      expect(dep5[:version_requested]).to eq('0.4.0')
      expect(dep5[:version_label]).to eq('0.3')
      expect(dep5[:comperator]).to eq('^')
      expect(dep5[:outdated]).to be_truthy

      dep6 = project.dependencies[5]
      expect(dep6[:name]).to eq(product7[:name])
      expect(dep6[:prod_key]).to eq(product7[:prod_key])
      expect(dep6[:language]).to eq(product7[:language])
      expect(dep6[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep6[:version_requested]).to eq('2.0.0')
      expect(dep6[:version_label]).to eq('1.2.0')
      expect(dep6[:comperator]).to eq('^')
      expect(dep6[:outdated]).to be_falsey

      dep7 = project.dependencies[6]
      expect(dep7[:name]).to eq(product8[:name])
      expect(dep7[:prod_key]).to eq(product8[:prod_key])
      expect(dep7[:language]).to eq(product8[:language])
      expect(dep7[:scope]).to eq(Dependency::A_SCOPE_DEVELOPMENT)
      expect(dep7[:version_requested]).to eq('0.3')
      expect(dep7[:version_label]).to eq('0.3')
      expect(dep7[:comperator]).to eq('=')
      expect(dep7[:outdated]).to be_truthy

      dep8 = project.dependencies[7]
      expect(dep8[:name]).to eq(product9[:name])
      expect(dep8[:prod_key]).to eq(product9[:prod_key])
      expect(dep8[:language]).to eq(product9[:language])
      expect(dep8[:scope]).to eq(Dependency::A_SCOPE_BUILD)
      expect(dep8[:version_requested]).to eq('0.9')
      expect(dep8[:version_label]).to eq('0.3')
      expect(dep8[:comperator]).to eq('>')
      expect(dep8[:outdated]).to be_falsey

      dep9 = project.dependencies[8]
      expect(dep9[:name]).to eq(product10[:name])
      expect(dep9[:prod_key]).to eq(product10[:prod_key])
      expect(dep9[:language]).to eq(product10[:language])
      expect(dep9[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep9[:version_requested]).to eq('0.5.0')
      expect(dep9[:version_label]).to eq('0.4.0')
      expect(dep9[:comperator]).to eq('^')
      expect(dep9[:outdated]).to be_falsey
      expect(dep9[:target]).to eq('windows')

      dep10 = project.dependencies[9]
      expect(dep10[:name]).to eq(product11[:name])
      expect(dep10[:prod_key]).to eq(product11[:prod_key])
      expect(dep10[:language]).to eq(product11[:language])
      expect(dep10[:scope]).to eq(Dependency::A_SCOPE_DEVELOPMENT)
      expect(dep10[:version_requested]).to eq('0.0.2')
      expect(dep10[:comperator]).to eq('^')
      expect(dep10[:outdated]).to be_falsey
      expect(dep10[:target]).to eq('unix')

      dep11 = project.dependencies[10]
      expect(dep11[:name]).to eq(product12[:name])
      expect(dep11[:prod_key]).to eq(product12[:prod_key])
      expect(dep11[:language]).to eq(product12[:language])
      expect(dep11[:scope]).to eq(Dependency::A_SCOPE_COMPILE)
      expect(dep11[:version_requested]).to eq('0.4.0')
      expect(dep11[:comperator]).to eq('^')
      expect(dep11[:outdated]).to be_falsey
      expect(dep11[:target]).to eq('i686-pc-windows-gnu')

    end
  end
end
