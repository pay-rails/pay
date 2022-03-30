require "base64"
require "json"
require "openssl"

module Pay
  module Paddle
    module Webhooks
      class SignatureVerifier
        def initialize(data)
          @data = data
          @public_key_file = Pay::Paddle.public_key_file
          @public_key = Pay::Paddle.public_key
          @public_key_base64 = Pay::Paddle.public_key_base64
        end

        def verify
          data = @data
          public_key = @public_key if @public_key
          public_key = File.read(@public_key_file) if @public_key_file
          public_key = Base64.decode64(@public_key_base64) if @public_key_base64
          return false unless data && data["p_signature"] && public_key

          # 'data' represents all of the POST fields sent with the request.
          # Get the p_signature parameter & base64 decode it.
          signature = Base64.decode64(data["p_signature"])

          # Remove the p_signature parameter
          data.delete("p_signature")

          # Ensure all the data fields are strings
          data.each { |key, value| data[key] = String(value) }

          # Sort the data
          data_sorted = data.sort_by { |key, value| key }

          # and serialize the fields
          # serialization library is available here: https://github.com/jqr/php-serialize
          data_serialized = serialize(data_sorted, true)

          # verify the data
          digest = OpenSSL::Digest.new("SHA1")
          pub_key = OpenSSL::PKey::RSA.new(public_key)
          pub_key.verify(digest, signature, data_serialized)
        end

        private

        # https://github.com/jqr/php-serialize/blob/master/lib/php_serialize.rb
        #
        # Returns a string representing the argument in a form PHP.unserialize
        # and PHP's unserialize() should both be able to load.
        #
        #   string = PHP.serialize(mixed var[, bool assoc])
        #
        # Array, Hash, Fixnum, Float, True/FalseClass, NilClass, String and Struct
        # are supported; as are objects which support the to_assoc method, which
        # returns an array of the form [['attr_name', 'value']..].  Anything else
        # will raise a TypeError.
        #
        # If 'assoc' is specified, Array's who's first element is a two value
        # array will be assumed to be an associative array, and will be serialized
        # as a PHP associative array rather than a multidimensional array.
        def serialize(var, assoc = false)
          s = ""
          case var
          when Array
            s << "a:#{var.size}:{"
            if assoc && var.first.is_a?(Array) && (var.first.size == 2)
              var.each do |k, v|
                s << serialize(k, assoc) << serialize(v, assoc)
              end
            else
              var.each_with_index do |v, i|
                s << "i:#{i};#{serialize(v, assoc)}"
              end
            end
            s << "}"
          when Hash
            s << "a:#{var.size}:{"
            var.each do |k, v|
              s << "#{serialize(k, assoc)}#{serialize(v, assoc)}"
            end
            s << "}"
          when Struct
            # encode as Object with same name
            s << "O:#{var.class.to_s.bytesize}:\"#{var.class.to_s.downcase}\":#{var.members.length}:{"
            var.members.each do |member|
              s << "#{serialize(member, assoc)}#{serialize(var[member], assoc)}"
            end
            s << "}"
          when String, Symbol
            s << "s:#{var.to_s.bytesize}:\"#{var}\";"
          when Integer
            s << "i:#{var};"
          when Float
            s << "d:#{var};"
          when NilClass
            s << "N;"
          when FalseClass, TrueClass
            s << "b:#{var ? 1 : 0};"
          else
            if var.respond_to?(:to_assoc)
              v = var.to_assoc
              # encode as Object with same name
              s << "O:#{var.class.to_s.bytesize}:\"#{var.class.to_s.downcase}\":#{v.length}:{"
              v.each do |k, v|
                s << "#{serialize(k.to_s, assoc)}#{serialize(v, assoc)}"
              end
              s << "}"
            else
              raise TypeError, "Unable to serialize type #{var.class}"
            end
          end
          s
        end
      end
    end
  end
end
