module Pay
  class Currency
    include ActionView::Helpers::NumberHelper

    attr_reader :attributes

    def self.all
      @currencies ||= begin
        path = Engine.root.join("config", "currencies", "iso.json")
        JSON.parse File.read(path)
      end
    end

    # Takes an amount (in cents) and currency and returns the formatted version for the currency
    def self.format(amount, currency:, **options)
      currency ||= :usd
      new(currency).format_amount(amount, **options)
    end

    def initialize(iso_code)
      @attributes = self.class.all[iso_code.to_s.downcase]
    end

    def format_amount(amount, **options)
      number_to_currency(
        amount.to_f / subunit_to_unit.to_f,
        {
          precision: precision + additional_precision(amount),
          unit: unit,
          separator: separator,
          delimiter: delimiter,
          format: format
        }.compact.merge(options)
      )
    end

    # Returns the precision to display
    #
    # If 1, returns 0
    # If 100, returns 2
    # If 1000, returns 3
    def precision
      subunit_to_unit.digits.count - 1
    end

    # If amount is 0.8, we want to display $0.008
    def additional_precision(amount)
      _, decimals = amount.to_s.split(".")
      decimals&.length || 0
    end

    def unit
      attributes["unit"]
    end

    def separator
      attributes["separator"]
    end

    def delimiter
      attributes["delimiter"]
    end

    def format
      attributes["format"]
    end

    def subunit?
      subunit.blank?
    end

    def subunit
      attributes["subunit"]
    end

    def subunit_to_unit
      attributes["subunit_to_unit"]
    end
  end
end
