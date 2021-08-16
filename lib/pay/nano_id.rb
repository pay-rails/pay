module Pay
  module NanoId
    # Generates unique IDs - faster than UUID
    ALPHABET = "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".freeze
    ALPHABET_SIZE = ALPHABET.size

    def self.generate(size: 21)
      id = ""
      size.times { id << ALPHABET[(Random.rand * ALPHABET_SIZE).floor] }
      id
    end
  end
end
