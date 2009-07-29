class String

  ##
  ## NOTE: you will want to translit non-ascii slugs to ascii.
  ## resist this impulse. nameized strings must remain utf8.
  ##
  ## NOTE2: iconv is total evil. however this seems really cool:
  ## http://github.com/svenfuchs/stringex/tree/master
  ##

  def nameize
    str = self.dup
    str.gsub!(/&(\w{2,6}?|#[0-9A-Fa-f]{2,6});/,'') # remove html entitities
    str.gsub!(/[^\w\+]+/, ' ') # all non-word chars to spaces
    str.strip!            # ohh la la
    str.downcase!         # upper case characters in urls are confusing
    str.gsub!(/\ +/, '-') # spaces to dashes, preferred separator char everywhere
    return str[0..49]
  end

  def denameize
    self.gsub('-',' ')
  end

  # returns false if any char is detected that is not allowed in
  # 'nameized' strings
  def nameized?
    self == self.nameize
  end

  def shell_escape
    if empty?
      "''"
    elsif self =~ %r{\A[0-9A-Za-z+_-]+\z}
      self
    else
      result = ''
      scan(/('+)|[^']+/) do
        if $1
          result << %q{\'} * $1.length
        else
          result << %Q{'#{$&}'}
        end
      end
      result
    end
  end

  #
  # replaces the symbols in a string
  # eg
  #  'I love {color} {thing}'.replace_symbols(:color => 'green', :thing => 'trees')
  # produces:
  #  'I love green trees'
  #
  def percent_with_hash(hash)
    if hash.is_a? Hash
      str = self.dup
      hash.each do |key, value|
        str.gsub! /:#{key}/, value.to_s
        str.gsub! /\{#{key}\}/, value.to_s
      end
      str
    else
      percent_without_hash(hash)
    end
  end
  alias :percent_without_hash :%
  alias :% :percent_with_hash

  # :call-seq:
  #   str.index_split(pattern) => anArray
  #
  # Split the string for each match of the regular expression _pattern_.
  # Unlike String#split, this method does not remove the _pattern_ from the input string.
  # #index_split slices the string on the starting index of each _pattern_ match.
  #
  # Returns +str+ if the pattern does not match
  def index_split(pattern)
    indexes = [0]
    last_index = 0

    # find every location where pattern matches
    while index = self.index(pattern, last_index + 1)
      indexes << index
      last_index = index
    end

    # find substrings
    substrings = []

    indexes.each_with_index do |str_index, i|
      start_offset = str_index

      end_offset = indexes[i + 1]
      end_offset ||= self.length

      substrings << self.slice(start_offset...end_offset)
    end

    return substrings
  end

  # just like any?() but instead of true returns the actual string.
  # useful like:
  #  str = str_a.any or atr_b.any
  #
  def any
    any? ? self : nil
  end

end

