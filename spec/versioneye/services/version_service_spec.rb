require 'spec_helper'

describe VersionService do

  let( :product ) { Product.new }


  describe "equal" do

    it "is equal" do
      expect( VersionService.equal("0.4.0", "0.4.0") ).to be_truthy
    end
    it "is equal" do
      expect( VersionService.equal("0.4", "0.4.0") ).to be_truthy
    end
    it "is not equal" do
      expect( VersionService.equal("1.4", "0.4.0") ).to be_falsy
    end

  end


  describe "newest_version" do

    it "returns the newest stable version" do
      product.versions.push( Version.new({:version => "1.0" }) )
      product.versions.push( Version.new({:version => "1.1" }) )
      newest = VersionService.newest_version( product.versions )
      expect( newest.version ).to eql("1.1")
    end

    it "returns the newest stable version" do
      product.versions.push( Version.new({:version => "1.0" }) )
      product.versions.push( Version.new({:version => "1.1-dev" }) )
      newest = VersionService.newest_version( product.versions )
      expect( newest.version ).to eql("1.0")
    end

    it "returns the newest dev version" do
      product.versions.push( Version.new({:version => "1.0" }) )
      product.versions.push( Version.new({:version => "1.1-dev" }) )
      newest = VersionService.newest_version( product.versions, VersionTagRecognizer::A_STABILITY_DEV )
      expect( newest.version ).to eql("1.1-dev")
    end

    it "returns the newest RC version" do
      product.versions.push( Version.new({:version => "3.2.13" }) )
      product.versions.push( Version.new({:version => "3.2.13.rc2" }) )
      newest = VersionService.newest_version( product.versions, VersionTagRecognizer::A_STABILITY_RC )
      expect( newest.version ).to eql("3.2.13")
    end

    it "returns the newest dev version because there is no stable" do
      product.versions.push( Version.new({:version => "1.0-Beta" }) )
      product.versions.push( Version.new({:version => "1.1-dev"  }) )
      newest = VersionService.newest_version( product.versions )
      expect( newest.version ).to eql("1.1-dev")
    end

    it "returns the newest dev version because the other one is dev-master" do
      product.versions.push( Version.new({:version => "dev-master" }) )
      product.versions.push( Version.new({:version => "1.1-dev"  }) )
      newest = VersionService.newest_version( product.versions, VersionTagRecognizer::A_STABILITY_DEV )
      expect( newest.version ).to eql("1.1-dev")
    end

    it "returns the dev-master because it is the only one" do
      product.versions.push( Version.new({:version => "dev-master" }) )
      newest = VersionService.newest_version( product.versions, VersionTagRecognizer::A_STABILITY_DEV )
      expect( newest.version ).to eql("dev-master")
    end

    it "returns the newest value from minor patches" do
      versions = []
      versions << Version.new(version: "2.0.1")
      versions << Version.new(version: "2.0.1-dev")
      versions << Version.new(version: "2.0.2-dev")
      versions << Version.new(version: "2.0.2")
      versions << Version.new(version: "2.0.3")
      versions << Version.new(version: "2.0.4")
      versions << Version.new(version: "2.0.4-dev")
      versions << Version.new(version: "2.0.5")
      versions << Version.new(version: "2.0.5-dev")

      newest = VersionService.newest_version(versions)
      expect( newest ).not_to be_nil
      expect( newest[:version] ).to eq("2.0.5")
    end

  end

  describe "versions_by_whitelist" do
    before :each do
      product.versions = []
    end

    it "returns empty list when whitelist is nil" do
      product.versions << Version.new(version: "0.1")
      allowed_versions = VersionService.versions_by_whitelist(product.versions, nil)
      expect( allowed_versions ).to be_empty
    end

    it "returns empty list when whitelist is just empty array" do
      product.versions << Version.new(version: "0.1")
      allowed_versions = VersionService.versions_by_whitelist(product.versions, [])
      expect( allowed_versions ).to be_empty
    end

    it "returns empty list when whitelist has no matching versions" do
      product.versions << Version.new(version: "0.1")
      allowed_versions = VersionService.versions_by_whitelist(product.versions, ["2.0"])
      expect( allowed_versions ).to be_empty
    end

    it "returns correct version when whitelist has only one version" do
      product.versions << Version.new(version: "0.1")
      product.versions << Version.new(version: "0.2")
      product.versions << Version.new(version: "1.2")
      allowed_versions = VersionService.versions_by_whitelist(product.versions, ["0.2"])

      expect( allowed_versions ).not_to be_empty
      expect( allowed_versions.first[:version] ).to eq("0.2")
    end

    it "returns correct versions when whitelist has many matching versions" do
      product.versions << Version.new(version: "0.1")
      product.versions << Version.new(version: "0.2")
      product.versions << Version.new(version: "1.2")
      allowed_versions = VersionService.versions_by_whitelist(product.versions, ["0.2", "1.0", "1.2"])

      expect( allowed_versions ).not_to be_empty
      expect( allowed_versions.size ).to eq(2)
      expect( allowed_versions[0][:version] ).to eq("0.2")
      expect( allowed_versions[1][:version] ).to eq("1.2")
    end


  end


  describe "newest_version_number" do

    it "returns the newest version correct." do
      product.versions = Array.new
      ver = 1
      5.times{
        version = Version.new
        version.version = ver.to_s
        ver += 1
        product.versions.push(version)
      }
      version = VersionService.newest_version_number( product.versions )

      expect( version ).to eql("5")
    end

    it "returns the newest version correct. With decimal numbers." do
      product.versions = Array.new
      ver = 1
      5.times{
        version = Version.new
        version.version = "1." + ver.to_s
        ver += 1
        product.versions.push(version)
      }
      version = VersionService.newest_version_number( product.versions )
      expect( version ).to eql("1.5")
    end

    it "returns the newest version correct. With long numbers." do
      product.versions = Array.new
      product.versions.push( Version.new({ :version => "1.2.2" }) )
      product.versions.push( Version.new({ :version => "1.2.29" }) )
      product.versions.push( Version.new({ :version => "1.3" }) )
      version = VersionService.newest_version_number( product.versions )

      expect( version ).to eql("1.3")
    end

    it "returns the newest version correct. With long numbers. Wariant 2." do
      product.versions = Array.new
      product.versions.push( Version.new({ :version => "1.22" }) )
      product.versions.push( Version.new({ :version => "1.229" }) )
      product.versions.push( Version.new({ :version => "1.30" }) )
      version = VersionService.newest_version_number( product.versions )

      expect( version ).to eql("1.229")
    end

  end

  describe "newest_version_from" do

    it "returns the correct version" do
      versions = Array.new
      versions.push( Version.new({ :version => "1.22"  }) )
      versions.push( Version.new({ :version => "1.229" }) )
      versions.push( Version.new({ :version => "1.30"  }) )

      expect( VersionService.newest_version_from(versions).version ).to eql("1.229")
    end

  end

  describe "newest_version_from_wildcard" do
    it "returns newest version for 1.x" do
      versions = []
      versions << Version.new({version: "0.1"})
      versions << Version.new({version: "0.9"})
      versions << Version.new({version: "1.0"})
      versions << Version.new({version: "1.1"})
      versions << Version.new({version: "1.5"})
      versions << Version.new({version: "1.7"})

      newest = VersionService.newest_version_from_wildcard(versions, '1.X')
      expect( newest ).not_to be_nil
      expect( newest ).to eq("1.7")
    end

    it "returns newest version for 2.0.*" do
      versions = []
      versions << Version.new({version: "2.0.1"})
      versions << Version.new({version: "2.0.5"})
      versions << Version.new({version: "2.0.5-alpha"})
      versions << Version.new({version: "2.1.1"})

      newest = VersionService.newest_version_from_wildcard(versions, '2.0.*')
      expect( newest ).not_to be_nil
      expect( newest ).to eq('2.0.5')
    end

  end

  describe "version_approximately_greater_than_starter" do

    it "returns the given value" do
      expect( VersionService.version_approximately_greater_than_starter("1.0") ).to eql("1.")
    end
    it "returns the given value" do
      expect( VersionService.version_approximately_greater_than_starter("1.2") ).to eql("1.")
    end
    it "returns the given value" do
      expect( VersionService.version_approximately_greater_than_starter("1.2.3") ).to eql("1.2.")
    end
  end


  describe "version_tilde_newest" do

    # TODO make it work with 1.345
    it "returns the right value" do
      product.versions = Array.new
      product.versions.push( Version.new({:version => "1.0"}) )
      product.versions.push( Version.new({:version => "1.1"}) )
      product.versions.push( Version.new({:version => "1.2"}) )
      product.versions.push( Version.new({:version => "1.3"}) )
      product.versions.push( Version.new({:version => "2.0"}) )
      tilde_version = VersionService.version_tilde_newest(product.versions, "1.2")

      expect( tilde_version.version ).to eql("1.3")
    end

    it "returns the right value" do
      product.versions = Array.new
      product.versions.push( Version.new({:version => "1.0"}) )
      product.versions.push( Version.new({:version => "1.2"}) )
      product.versions.push( Version.new({:version => "1.3"}) )
      product.versions.push( Version.new({:version => "1.4"}) )
      product.versions.push( Version.new({:version => "2.0"}) )
      tilde_version = VersionService.version_tilde_newest(product.versions, "1.2")

      expect( tilde_version.version ).to eql("1.4")
    end

    it "returns the right value" do
      product.versions = Array.new
      product.versions.push( Version.new({:version => "2.0.0"}) )
      product.versions.push( Version.new({:version => "2.2.0"}) )
      product.versions.push( Version.new({:version => "2.3.0"}) )
      product.versions.push( Version.new({:version => "2.3.1"}) )
      product.versions.push( Version.new({:version => "3.0.0"}) )
      tilde_version = VersionService.version_tilde_newest( product.versions, "~2.1" )

      expect( tilde_version.version ).to eql("2.3.1")
    end

    it "returns the right value" do
      product.versions = Array.new
      product.versions.push( Version.new({:version => "3.7.29"}) )
      product.versions.push( Version.new({:version => "3.0.0"}) )
      product.versions.push( Version.new({:version => "2.3.0"}) )
      product.versions.push( Version.new({:version => "2.3.1"}) )
      product.versions.push( Version.new({:version => "3.0.1"}) )
      tilde_version = VersionService.version_tilde_newest( product.versions, "~3.0" )

      expect( tilde_version.version ).to eql("3.7.29")
    end

    it "returns the right value" do
      product.versions = Array.new
      product.versions.push( Version.new({:version => "3.7.29"}) )
      product.versions.push( Version.new({:version => "3.0.0"}) )
      product.versions.push( Version.new({:version => "2.3.0"}) )
      product.versions.push( Version.new({:version => "2.3.1"}) )
      product.versions.push( Version.new({:version => "3.0.1"}) )
      tilde_version = VersionService.version_tilde_newest( product.versions, "~3" )

      expect( tilde_version.version ).to eql("3.7.29")
    end

  end

  describe "version_tilde_newest" do
    it "returns the right value 2.0.0" do
      expect( VersionService.tile_border( "1.2" ) ).to eql("2.0")
    end
    it "returns the right value 2.0.0" do
      expect( VersionService.tile_border( "1.2.1" ) ).to eql("1.3")
    end
    it "returns the right value 2.0.0" do
      expect( VersionService.tile_border( "1.2.1-1" ) ).to eql("1.3")
    end
    it "returns the right value 2.0.0" do
      expect( VersionService.tile_border( "1.2.1_1" ) ).to eql("1.3")
    end
    it "returns the right value 2.0.0" do
      expect( VersionService.tile_border( "1.2.1_RC" ) ).to eql("1.3")
    end
    it "returns the right value 3" do
      expect( VersionService.tile_border( 2 ) ).to eql( 3 )
    end
  end

  describe "get_version_range" do

    it "returns the right range" do
      product.versions = Array.new
      product.versions.push( Version.new({ :version => "1.0" }) )
      product.versions.push( Version.new({ :version => "1.1" }) )
      product.versions.push( Version.new({ :version => "1.2" }) )
      product.versions.push( Version.new({ :version => "1.3" }) )
      product.versions.push( Version.new({ :version => "1.4" }) )

      range = VersionService.version_range(product.versions, "1.1", "1.3")
      expect( range.count ).to eql(3)
      expect( range.first.version ).to eql("1.1")
      expect( range.last.version ).to  eql("1.3")
    end

  end

  describe "versions_start_with" do

    it "returns an empty array" do
      expect( VersionService.versions_start_with(nil, "1.0") ).to eql([])
    end

    it "returns the correct array" do
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      product.versions.push( Version.new( { :version => "1.3" } ) )
      product.versions.push( Version.new( { :version => "2.0" } ) )
      results = VersionService.versions_start_with(product.versions, "1")

      expect( results.size ).to eql(3)
      expect( results.first.version ).to eql("1.1")
      expect( results.last.version ).to  eql("1.3")

      results = VersionService.versions_start_with(product.versions, "1.")
      expect( results.size ).to eql(3)
      expect( results.first.version ).to eql("1.1")
      expect( results.last.version ).to eql("1.3")
    end

  end

  describe "newest_but_not" do
    let(:versions){[]}
    before :each do
      versions << Version.new(version: "1.1")
      versions << Version.new(version: "1.2")
      versions << Version.new(version: "1.3")
    end

    it "returns the newest value except the one specific value" do
      result = VersionService.newest_but_not(versions, "1.3")
      expect( result ).not_to be_nil
      expect( result[:version] ).to eq("1.2")
    end
  end

  describe "get_greater_than" do

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      ver = VersionService.greater_than(product.versions, "1.1")

      expect( ver.version ).to eql("1.2")
    end

  end


  describe "greater_than_or_equal" do

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      ver = VersionService.greater_than_or_equal(product.versions, "1.1")
      expect( ver.version ).to eql("1.2")
    end

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      ver = VersionService.greater_than_or_equal(product.versions, "1.1")

      expect( ver.version ).to eql("1.1")
    end

  end


  describe "smaller_than" do

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      ver = VersionService.smaller_than(product.versions, "1.1")

      expect( ver.version ).to eql("1.0")
    end

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.2.2" } ) )
      product.versions.push( Version.new( { :version => "2.2.3" } ) )
      product.versions.push( Version.new( { :version => "2.3.0" } ) )
      ver = VersionService.smaller_than(product.versions, "2.4-dev")

      expect( ver.version ).to eql("2.3.0")
    end

  end


  describe "smaller_than_or_equal" do

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      ver = VersionService.smaller_than_or_equal(product.versions, "1.1")

      expect( ver.version ).to eql("1.1")
    end

    it "returns the highest value" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      ver = VersionService.smaller_than_or_equal(product.versions, "1.1")

      expect( ver.version ).to eql("1.0")
    end

  end


  describe "from_ranges" do

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      product.versions.push( Version.new( { :version => "1.3" } ) )
      versions = VersionService.from_ranges(product.versions, ">=1.0, <1.2")

      expect( versions.size ).to eq(2)
      expect( versions.first.to_s ).to eq("1.0")
      expect( versions.last.to_s ).to eq("1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      product.versions.push( Version.new( { :version => "1.3" } ) )
      versions = VersionService.from_ranges(product.versions, ">1.0, <1.2")

      expect( versions.size ).to eq(1)
      expect( versions.first.to_s ).to eq("1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      product.versions.push( Version.new( { :version => "1.3" } ) )
      versions = VersionService.from_ranges(product.versions, ">=1.0, <=1.2")

      expect( versions.size ).to eq(3)
      expect( versions.first.to_s ).to eq("1.0")
      expect( versions.last.to_s  ).to eq("1.2")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "1.0" } ) )
      product.versions.push( Version.new( { :version => "1.1" } ) )
      product.versions.push( Version.new( { :version => "1.2" } ) )
      product.versions.push( Version.new( { :version => "1.3" } ) )
      versions = VersionService.from_ranges(product.versions, ">=1.0, !=1.2")

      expect( versions.size ).to eq(3)
      expect( versions.first.to_s ).to eq("1.0")
      expect( versions.last.to_s ).to eq("1.3")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, ">=2.0.0, <2.0.11")

      expect( versions.size ).to eq(4)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.0.10")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, "<2.1.0")

      expect( versions.size ).to eq(5)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.0.11")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, "2.0.0, 2.1.1")

      expect( versions.size ).to eq(2)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, "<2.0.1, 2.1.1")

      expect( versions.size ).to eq(2)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, "2.0.X")

      expect( versions.size ).to eq(5)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.0.11")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, "2.0.X, 2.1.X")

      expect( versions.size ).to eq(6)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_ranges(product.versions, "~> 2.0.0")

      expect( versions.size ).to eq(5)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.0.11")
    end

  end


  describe 'from_or_ranges' do
    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.10.0" } ) )
      product.versions.push( Version.new( { :version => "3.10.0" } ) )
      product.versions.push( Version.new( { :version => "3.11.0" } ) )
      product.versions.push( Version.new( { :version => "3.12.0" } ) )
      product.versions.push( Version.new( { :version => "4.0.0" } ) )
      product.versions.push( Version.new( { :version => "4.1.0" } ) )
      product.versions.push( Version.new( { :version => "4.2.0" } ) )
      product.versions.push( Version.new( { :version => "4.3.0" } ) )
      product.versions.push( Version.new( { :version => "4.4.0" } ) )
      product.versions.push( Version.new( { :version => "4.5.0" } ) )
      product.versions.push( Version.new( { :version => "4.6.0" } ) )
      versions = VersionService.from_or_ranges(product.versions, "<3.11 || >= 4 <4.5")

      expect( versions.size ).to eq(7)
      expect( versions.first.to_s ).to eq("2.10.0")
      expect( versions.last.to_s ).to eq("4.4.0")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.0.10" } ) )
      product.versions.push( Version.new( { :version => "2.0.11" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_or_ranges(product.versions, "2.0.X, 2.1.X")

      expect( versions.size ).to eq(6)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      product.versions.push( Version.new( { :version => "2.0.2" } ) )
      product.versions.push( Version.new( { :version => "2.1.0" } ) )
      product.versions.push( Version.new( { :version => "2.1.1" } ) )
      product.versions.push( Version.new( { :version => "2.2.5" } ) )
      versions = VersionService.from_or_ranges(product.versions, "2.0.x || 2.1.x")

      expect( versions.size ).to eq(5)
      expect( versions.first.to_s ).to eq("2.0.0")
      expect( versions.last.to_s ).to eq("2.1.1")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      versions = VersionService.from_or_ranges(product.versions, "=2.0.0")

      expect( versions.size ).to eq(1)
      expect( versions.first.to_s ).to eq("2.0.0")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      versions = VersionService.from_or_ranges(product.versions, "==2.0.0")

      expect( versions.size ).to eq(1)
      expect( versions.first.to_s ).to eq("2.0.0")
    end

    it "returns the right values" do
      product.versions = Array.new
      product.versions.push( Version.new( { :version => "2.0.0" } ) )
      product.versions.push( Version.new( { :version => "2.0.1" } ) )
      versions = VersionService.from_or_ranges(product.versions, "2.0.0")

      expect( versions.size ).to eq(1)
      expect( versions.first.to_s ).to eq("2.0.0")
    end
  end

  describe 'from_common_range' do
    before do
      product.versions = []
      product.versions << Version.new(version: '0.2.8')
      product.versions << Version.new(version: '0.4.0')
      product.versions << Version.new(version: '0.6.0')
      product.versions << Version.new(version: '0.6.2')
      product.versions << Version.new(version: '0.7.0')
      product.versions << Version.new(version: '1.0.0')

      product.save
    end

    it "returns the right value for closed range `>= 0.3, < 0.7`" do
      highest_version = VersionService.from_common_range(product.versions, '>= 0.3, < 0.7', false)
      expect( highest_version ).not_to be_nil
      expect( highest_version[:version]).to eq('0.6.2')
    end

    it "returns the latest version when right border is open" do
      highest_version = VersionService.from_common_range(product.versions, '> 0.5', false)
      expect( highest_version ).not_to be_nil
      expect( highest_version[:version]).to eq('1.0.0')
    end
  end

  context "caret_lower_border" do
    it "returns correct semver strings" do
      expect( VersionService.caret_lower_border("1.2.3")).to eq('1.2.3')
      expect( VersionService.caret_lower_border("1.2.3-alpha")).to eq('1.2.3')
      expect( VersionService.caret_lower_border("1.2.3-beta")).to eq('1.2.3')

      expect( VersionService.caret_lower_border('1.2') ).to eq('1.2.0')
      expect( VersionService.caret_lower_border('0.2.3') ).to eq('0.2.3')
      expect( VersionService.caret_lower_border('0.0.3') ).to eq('0.0.3')
      expect( VersionService.caret_lower_border('0.0')).to eq('0.0.0')
      expect( VersionService.caret_lower_border('0')).to eq('0.0.0')
    end
  end

  context "caret_upper_border" do
    it "returns correct upper lever semver" do
      expect( VersionService.caret_upper_border('1.2.3') ).to eq('2.0.0')
      expect( VersionService.caret_upper_border('1.2') ).to eq('2.0.0')
      expect( VersionService.caret_upper_border('1') ).to eq('2.0.0')
      expect( VersionService.caret_upper_border('0.2.3')).to eq('0.3.0')
      expect( VersionService.caret_upper_border('0.3') ).to eq('0.4.0')
      expect( VersionService.caret_upper_border('0.0.3')).to eq('0.0.4')
      expect( VersionService.caret_upper_border('0.0.0')).to eq('1.0.0')
    end
  end

  describe 'newest_caret_version' do
    it "returns for ^0 biggest value in the range 0 <= x < 1.0.0" do
      versions = ['0.0.9', '0.1.0', '0.9.2', '1.0.0', '1.0.1', '1.2.0']
      expect( VersionService.newest_caret_version(versions, '0') ).to eq('0.9.2')
    end

    it "returns for ^0.1 biggest value in the range 0.1 <= x < 0.2.0" do
      versions = ['0.0.9', '0.1.0', '0.1.9', '0.2.0', '0.2.1', '1.0.0']
      expect( VersionService.newest_caret_version(versions, '0.1') ).to eq('0.1.9')
    end

    it "returns for ^0.2.3 biggest value in the range 0.2.3 <= x < 0.3.0" do
      versions = ['0.1.0', '0.2.1', '0.2.3', '0.2.9', '0.2.11', '0.3.0', '0.3.1']
      expect( VersionService.newest_caret_version(versions, '0.2.3')).to eq('0.2.11')
    end

    it "returns for ^1.2.3 biggest value in the range 1.2.3 <= x < 2.0.0" do
      versions = ['1.2.2', '1.2.3', '1.2.9', '1.3.0', '1.5.2', '2.0.0', '2.0.1']
      expect( VersionService.newest_caret_version(versions, '1.2.3')).to eq('1.5.2')
    end

    it "returns for ^1.2 biggest value in the range 1.2.0 <= x < 2.0.0" do
      versions = ['1.2.2', '1.2.3', '1.2.9', '1.3.0', '1.5.2', '2.0.0', '2.0.1']
      expect( VersionService.newest_caret_version(versions, '1.2')).to eq('1.5.2')
    end

    it "returns for ^1 biggest value in the range 1.0 <= x < 2.0.0" do
      versions = ['0.9.0', '1.2.0', '1.2.9', '1.3.0', '1.5.2', '2.0.0', '2.0.1']
      expect( VersionService.newest_caret_version(versions, '1')).to eq('1.5.2')
    end


  end

  describe 'average_release_time' do

    it 'returns nil for nil' do
      expect( VersionService.average_release_time(nil) ).to be_nil
    end

    it 'returns nil for empty array' do
      expect( VersionService.average_release_time(Array.new) ).to be_nil
    end

    it 'returns nil for array with 1 element' do
      expect( VersionService.average_release_time([Version.new]) ).to be_nil
    end

    it 'returns nil for array with 2 elements' do
      expect( VersionService.average_release_time([Version.new, Version.new ]) ).to be_nil
    end

    it 'returns 1 day' do
      version_1 = Version.new :released_at => DateTime.new(2014, 01, 01)
      version_2 = Version.new :released_at => DateTime.new(2014, 01, 03)
      version_3 = Version.new :released_at => DateTime.new(2014, 01, 05)
      versions = [version_1, version_2, version_3]

      expect( VersionService.average_release_time( versions ) ).to eq(1)
    end

    it 'returns 20 day' do
      version_1 = Version.new :released_at => DateTime.new(2014, 01, 01)
      version_2 = Version.new :released_at => DateTime.new(2014, 02, 01)
      version_3 = Version.new :released_at => DateTime.new(2014, 03, 02)
      versions = [version_1, version_2, version_3]

      expect( VersionService.average_release_time( versions ) ).to eq(20)
    end

  end

  describe 'estimated_average_release_time' do

    it 'returns nil for nil' do
      expect( VersionService.estimated_average_release_time(nil) ).to be_nil
    end

    it 'returns nil for empty array' do
      expect( VersionService.estimated_average_release_time(Array.new) ).to be_nil
    end

    it 'returns nil for array with 1 element' do
      expect( VersionService.estimated_average_release_time([Version.new]) ).to be_nil
    end

    it 'returns 1 day' do
      version_1 = Version.new :created_at => DateTime.new(2014, 01, 01)
      version_2 = Version.new :created_at => DateTime.new(2014, 01, 03)
      version_3 = Version.new :created_at => DateTime.new(2014, 01, 05)
      versions = [version_1, version_2, version_3]

      expect( VersionService.estimated_average_release_time( versions ) ).to eq(1)
    end

    it 'returns 20 day' do
      version_1 = Version.new :created_at => DateTime.new(2014, 01, 01)
      version_2 = Version.new :created_at => DateTime.new(2014, 02, 01)
      version_3 = Version.new :created_at => DateTime.new(2014, 03, 02)
      versions = [version_1, version_2, version_3]

      expect( VersionService.estimated_average_release_time( versions ) ).to eq(20)
    end

  end

end
