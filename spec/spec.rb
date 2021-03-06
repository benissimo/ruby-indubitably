# encoding: utf-8
require "indubitably"

describe "indubitably" do
  describe "enumerable" do
    it "#each" do
      expect { |b| Some(1).each(&b) }.to yield_with_args(1)
      expect { |b| None().each(&b) }.not_to yield_with_args
    end

    it "#map" do
      expect(Some(2).map { |v| v * v }.get).to eql(4)
      expect { |b| None().map(&b) }.not_to yield_with_args
    end

    it "#reduce" do
      expect(Some(2).reduce(5) { |a, e| a * e }).to eql(10)
      expect { |b| None().reduce(&b) }.not_to yield_with_args
      expect(None().reduce(5) {}).to eql(5)
    end

    it "#select" do
      expect(Some(2).select(&:even?).get).to eql(2)
      expect(Some(1).select(&:even?).is_none?).to eql(true)
    end

    it "#flat_map" do
      div = lambda do |num, denom|
        if (denom == 0)
          Maybe(nil)
        else
          Maybe(num.to_f / denom.to_f)
        end
      end
      expect(Maybe(5).flat_map { |x| div.call(1, x) }).to eql(Maybe(0.2))
      expect(Maybe(0).flat_map { |x| div.call(1, x) }).to eql(None())
    end
  end

  context "joining nested monads" do
    let(:nested_none) { Maybe(None()) }
    let(:nested_some) { Maybe(Some(10)) }
    let(:deep_none) { Maybe(nested_none) }
    let(:deep_some) { Maybe(nested_some) }

    describe "#join" do
      it "joins a nested none into its parent" do
        expect(nested_none.join.is_none?).to eql(true)
      end

      it "joins a nested some into its parent" do
        expect(nested_some.join.get).to eql(10)
      end

      it "does not join recursively" do
        expect(deep_some.join.join.get).to eql(10)
      end
    end

    describe "#join!" do
      it "joins all Some instances recursively" do
        expect(deep_some.join!.get).to eql(10)
      end

      it "joins all None instances recursively" do
        expect(deep_none.join!.is_none?).to be_truthy
      end
    end
  end

  describe "values and non-values" do
    it "None" do
      expect(Maybe(nil).is_none?).to eql(true)
      expect(Maybe([]).is_none?).to eql(true)
      expect(Maybe("").is_none?).to eql(true)
    end

    it "Some" do
      expect(Maybe(0).is_some?).to eql(true)
      expect(Maybe(false).is_some?).to eql(true)
      expect(Maybe([1]).is_some?).to eql(true)
      expect(Maybe(" ").is_some?).to eql(true)
    end
  end

  describe "is_a" do
    it "Some" do
      expect(Some(nil).is_a?(None)).to eql(true)
      expect(Some(1).is_a?(Some)).to eql(true)
      expect(Some(1).is_a?(None)).to eql(false)
      expect(None().is_a?(Some)).to eql(false)
      expect(None().is_a?(None)).to eql(true)
      expect(Some(1).is_a?(Maybe)).to eql(true)
      expect(None().is_a?(Maybe)).to eql(true)
    end
  end

  describe "equality" do
    it "#eql?" do
      expect(Maybe(nil).eql? Maybe(nil)).to be true
      expect(Maybe(nil).eql? Maybe(5)).to be false
      expect(Maybe(5).eql? Maybe(5)).to be true
      expect(Maybe(3).eql? Maybe(5)).to be false
    end
  end

  describe "case equality" do
    it "#===" do
      expect(Some(1) === Some(1)).to be true
      expect(Maybe(1) === Some(2)).to be false
      expect(Some(1) === None).to be false
      expect(None === Some(1)).to be false
      expect(None === None()).to be true
      expect(Some((1..3)) === Some(2)).to be true
      expect(Some(Integer) === Some(2)).to be true
      expect(Maybe === Some(2)).to be true
      expect(Maybe === None()).to be true
      expect(Some === Some(6)).to be true
    end
  end

  describe "case expression" do
    def test_case_when(case_value, match_value, non_match_value)
      value =
          case case_value
          when non_match_value
            false
          when match_value
            true
          else
            false
          end

      expect(value).to be true
    end

    it "matches Some" do
      test_case_when(Maybe(1), Some, None)
    end

    it "matches None" do
      test_case_when(Maybe(nil), None, Some)
    end

    it "matches to integer value" do
      test_case_when(Maybe(1), Some(1), Some(2))
    end

    it "matches to range" do
      test_case_when(Maybe(1), Some((0..2)), Some((2..3)))
    end

    it "matches to lambda" do
      even = ->(a) { a.even? }
      odd = ->(a) { a.odd? }
      test_case_when(Maybe(2), Some(even), Some(odd))
    end
  end

  describe "to array" do
    it "#to_ary" do
      a, _ = Maybe(1)
      expect(a).to eql(1)
      expect([Maybe(1)].map { |(x)| x }).to eql([1])
    end

    it "#to_a" do
      expect(Maybe(1).to_a).to eql([1])
      expect(Maybe(nil).to_a).to eql([])
    end
  end

  describe "get and or_else" do
    it "get" do
      expect { None.get }.to raise_error
      expect(Some(1).get).to eql(1)
    end

    it "or_else" do
      expect(None().or_else(true)).to eql(true)
      expect(None().or_else { false }).to eql(false)
      expect(Some(1).or_else(2)).to eql(1)
      expect(Some(1).or_else { 2 }).to eql(1)
    end
  end

  describe "method forwarding" do
    it "forwards methods" do
      expect(Some("maybe").upcase.get).to eql("MAYBE")

      mapped = Some([1, 2, 3]).map { |arr| arr.map { |v| v * v } }
      expect(mapped.get).to eql([1, 4, 9])
    end

    describe "underscore methods" do
      let(:some_array) { Some([1, 2, 3, 4]) }

      it "applies methods that have equivalents in Maybe to the wrapped value" do
        expect(some_array._map { |n| n**2 }).to eq(Some([1, 4, 9, 16]))
      end

      it "applies methods without equivalents in Maybe to the wrapped value" do
        expect(Some("abc")._upcase).to eq(Some("ABC"))
      end

      it "works with Nones" do
        expect(None()._something.is_none?).to be_truthy
      end
    end

    describe "#respond_to?" do
      it "returns true if forwarded method exists" do
        expect(Some("maybe").respond_to?(:upcase)).to be_truthy
      end

      it "returns true if forwarded underscore method exists" do
        expect(Some([1, 2, 3]).respond_to?(:_map)).to be_truthy
      end

      it "returns true if chained forwarded underscore method exists" do
        expect(Some(Some([1, 2, 3])).respond_to?(:__map)).to be_truthy
      end

      it "returns false if method does not exist" do
        expect(Some("maybe").respond_to?(:crazy_pants)).to be_falsy
      end

      it "returns false if passed underscore method it can't forward" do
        expect(Some("maybe").respond_to?(:_crazy_pants)).to be_falsy
      end

      it "returns false if chained forwarded underscore method exists" do
        expect(Some(Some([1, 2, 3])).respond_to?(:__map)).to be_truthy
      end
    end

    describe "#method" do
      it "returns a method if forwarded method exists" do
        expect{ Some("maybe").method(:upcase)}.to_not raise_error
      end

      it "raises an error if forwarded method does not exist" do
        expect{ Some("maybe").method(:crazy_pants)}.to raise_error(NameError)
      end
    end
  end


  describe "if" do
    it "returns none if the condition is not met" do
      expect(Maybe(7).if { |x| x.even? }).to eq(None())
    end

    it "returns some if the condition is met" do
      expect(Maybe(4).if { |x| x.even? }).to eq(Some(4))
    end

    it "works with None" do
      expect(Maybe(nil).if { |x| x.even? }).to eq(None())
    end
  end
end
