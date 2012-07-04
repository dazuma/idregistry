# -----------------------------------------------------------------------------
#
# ObjectRegistry configuration object
#
# -----------------------------------------------------------------------------
# Copyright 2012 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------
;


require 'blockenspiel'


module ObjectRegistry


  # Raised if you attempt to modify the configuration of a registry for which
  # the configuration has been locked because you've started to add data.

  class ConfigurationLockedError < ::RuntimeError
  end


  # A registry configuration.
  #
  # Access this API by calling the configuration method of a registry.
  # Conceptually, the configuration and the registry are just two
  # windows (APIs) into the same object.
  #
  # Once objects are added to the registry, the configuration is locked
  # and cannot be modified. Informational methods may still be called.

  class Configuration


    def initialize(repository_, patterns_, types_, categories_)  # :nodoc:
      @repository = repository_
      @patterns = patterns_
      @types = types_
      @categories = categories_
      @locked = false
    end


    def inspect  # :nodoc:
      "#<#{self.class}:0x#{object_id.to_s(16)}>"
    end


    def lock
      @locked = true
    end


    def locked?
      @locked
    end


    def repository
      @repository
    end


    # Returns an array of all patterns known by this configuration.

    def all_patterns
      @patterns.keys
    end


    # Returns an array of all object types known by this configuration.

    def all_types
      @types.keys
    end


    # Returns an array of all category types known by this configuration.

    def all_categories
      @categories.keys
    end


    # Returns true if this configuration includes the given pattern.

    def has_pattern?(pattern_)
      @patterns.has_key?(pattern_)
    end


    # Returns true if this configuration includes the given object type.

    def has_type?(type_)
      @types.has_key?(type_)
    end


    # Returns true if this configuration includes the given category type.

    def has_category?(category_)
      @categories.has_key?(category_)
    end


    # Returns the object type corresponding to the given pattern.
    # Returns nil if the given pattern is not recognized.

    def type_for_pattern(pattern_)
      patdata_ = @patterns[pattern_]
      patdata_ ? patdata_[0] : nil
    end


    # Returns an array of patterns corresponding to the given object type.
    # Returns the empty array if the given object type is not recognized.

    def patterns_for_type(type_)
      typedata_ = @types[type_]
      typedata_ ? typedata_.dup : []
    end


    # Add a pattern to the configuration. You may either pass parameters
    # or pass a block that utilizes the PatternAdder DSL.
    #
    # [<tt>pattern_</tt>]
    #   The pattern to recognize. Must be an array.
    # [<tt>type_</tt>]
    #   The type of object this pattern should correspond to.
    #   Must be a string or a symbol.
    # [<tt>gen_obj_</tt>]
    #   A proc that is called to generate the appropriate object given a
    #   tuple.
    # [<tt>gen_tuple_</tt>]
    #   A proc that is called to generate the tuple given an object.

    def add_pattern(pattern_=nil, type_=nil, gen_obj_=nil, gen_tuple_=nil, &block_)
      raise ConfigurationLockedError if @locked
      if block_
        adder_ = PatternAdder._new(pattern_, type_, gen_obj_, gen_tuple_)
        ::Blockenspiel.invoke(block_, adder_)
        pattern_ = adder_.pattern
        type_ = adder_.type
        gen_obj_ = adder_._gen_obj_block
        gen_tuple_ = adder_._gen_tuple_block
      end
      pattern_ ||= []
      gen_obj_ ||= proc{nil}
      gen_tuple_ ||= proc{|obj_| []}
      if @patterns.has_key?(pattern_)
        false
      else
        @patterns[pattern_] = [type_, gen_obj_, gen_tuple_]
        (@types[type_] ||= []) << pattern_ if type_
        true
      end
    end


    # Remove the given pattern from this configuration.
    # Automatically removes the object type if this is the object type's
    # only remaining pattern.

    def delete_pattern(pattern_)
      raise ConfigurationLockedError if @locked
      patdata_ = @patterns.delete(pattern_)
      if patdata_
        typedata_ = @types[patdata_[0]]
        typedata_.delete(pattern_)
        @types.delete(patdata_[0]) if typedata_.empty?
        true
      else
        false
      end
    end


    # Remove the given object type from this configuration.
    # Automatically removes all patterns associated with this object type.

    def delete_type(type_)
      raise ConfigurationLockedError if @locked
      typedata_ = @types.delete(type_)
      if typedata_
        typedata_.each{ |pat_| @patterns.delete(pat_) }
        true
      else
        false
      end
    end


    # Add a category.
    #
    # TODO: Need to document what a category is.

    def add_category(category_, pattern_, indexes_)
      raise ConfigurationLockedError if @locked
      if @categories.has_key?(category_)
        false
      else
        @categories[category_] = [pattern_, indexes_, {}]
        true
      end
    end


    # Remove a category by name.

    def delete_category(category_)
      raise ConfigurationLockedError if @locked
      catdata_ = @categories.delete(category_)
      catdata_ ? true : false
    end


    # Clear all configuration.

    def clear
      raise ConfigurationLockedError if @locked
      @patterns.clear
      @types.clear
      @categories.clear
    end


    # Create a new empty registry, duplicating this configuration.
    # The new registry will have an unlocked configuration that can be
    # modified further.

    def spawn_registry
      patterns_ = {}
      types_ = {}
      categories_ = {}
      @patterns.each{ |k_, v_| patterns_[k_] = v_.dup }
      @types.each{ |k_, v_| types_[k_] = v_.dup }
      @categories.each{ |k_, v_| categories_[k_] = [v_[0], v_[1], {}] }
      Registry._new(patterns_, types_, categories_)
    end


    class << self

      # :stopdoc:
      alias_method :_new, :new
      private :new
      # :startdoc:

    end


  end


  # This is the DSL available within the block passed to
  # Configuration#add_pattern.

  class PatternAdder

    include ::Blockenspiel::DSL

    def initialize(pattern_, type_, gen_obj_, gen_tuple_)  # :nodoc:
      @pattern = pattern_
      @type = type_
      @gen_obj = gen_obj_
      @gen_tuple = gen_tuple_
    end


    def inspect  # :nodoc:
      "#<#{self.class}:0x#{object_id.to_s(16)}>"
    end


    # Set the pattern to add

    def pattern(value_=nil)
      if value_
        @pattern = value_
      else
        @pattern
      end
    end


    # Set the object type

    def type(value_=nil)
      if value_
        @type = value_
      else
        @type
      end
    end


    # Provide a block to call to generate the appropriate object given a
    # tuple. This block is called when the repository is asked to lookup
    # an object given a tuple, and the provided tuple is not yet present.
    #
    # The block may take up to three arguments.
    # The first is the tuple.
    # The second is the repository containing the object.
    # The third is a hash of arguments passed to the repository's lookup
    # method.
    #
    # The block should return the generated object, or nil if it is unable
    # to generate an object for the given tuple.

    def to_generate_object(&block_)
      @gen_obj = block_
    end


    # Provide a block to call to generate the tuple corresponding to an
    # object. The repository calls this block when an object is added, in
    # order to generate the appropriate tuples for looking up the object.

    def to_generate_tuple(&block_)
      @gen_tuple = block_
    end


    dsl_methods false

    def _gen_obj_block  # :nodoc:
      @gen_obj
    end


    def _gen_tuple_block  # :nodoc:
      @gen_tuple
    end


    class << self

      # :stopdoc:
      alias_method :_new, :new
      private :new
      # :startdoc:

    end


  end


end
