# -----------------------------------------------------------------------------
#
# IDRegistry configuration object
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


module IDRegistry


  # A registry configuration.
  #
  # Access this API by calling the configuration method of a registry.
  # Conceptually, the configuration and the registry are just two
  # windows (APIs) into the same object.
  #
  # Once objects are added to the registry, the configuration is locked
  # and cannot be modified. Informational methods may still be called.

  class Configuration

    include ::Blockenspiel::DSL

    dsl_methods false


    # Object types that aren't explicitly provided will be assigned
    # anonymous types that are instances of this class.

    class AnonymousType; end


    def initialize(registry_, patterns_, types_, categories_, methods_)  # :nodoc:
      @registry = registry_
      @patterns = patterns_
      @types = types_
      @categories = categories_
      @methods = methods_
      @locked = false
      @mutex = ::Mutex.new
    end


    def inspect  # :nodoc:
      "#<#{self.class}:0x#{object_id.to_s(16)}>"
    end


    # Returns true if this configuration has been locked.
    # A locked configuration can no longer be modified.
    # Registries lock their configurations once you start using them.

    def locked?
      @locked
    end


    # Returns the registry that owns this configuration.

    def registry
      @registry
    end


    # Create a new empty registry, duplicating this configuration.
    #
    # If the <tt>:unlocked</tt> option is set to true, the new registry
    # will have an unlocked configuration that can be modified further.
    # Otherwise, the new registry's configuration will be locked.
    #
    # Spawning a locked registry from a locked configuration is very fast
    # because it reuses the configuration objects.

    def spawn_registry(opts_={})
      request_unlocked_ = opts_[:unlocked]
      if @locked && !request_unlocked_
        reg_ = Registry._new(@patterns, @types, @categories, @methods)
        reg_.config.lock
      else
        patterns_ = {}
        types_ = {}
        categories_ = {}
        methods_ = {}
        @mutex.synchronize do
          @patterns.each{ |k_, v_| patterns_[k_] = v_.dup }
          @types.each{ |k_, v_| types_[k_] = v_.dup }
          @categories.each{ |k_, v_| categories_[k_] = v_.dup }
          @methods.each{ |k_, v_| methods_[k_] = v_.dup }
        end
        reg_ = Registry._new(patterns_, types_, categories_, methods_)
        reg_.config.lock unless request_unlocked_
      end
      reg_
    end


    dsl_methods true


    # Lock the configuration, preventing further changes.
    #
    # This is called by registries when you start using them.
    #
    # In addition, it is cheap to spawn another registry from a
    # configuration that is locked, because the configuration internals
    # can be reused. Therefore, you should lock a configuration if you
    # want to use it as a template to create empty registries quickly
    # (using the spawn_registry call).

    def lock
      @mutex.synchronize do
        @locked = true
      end
      self
    end


    # Returns an array of all patterns known by this configuration.
    #
    # The pattern arrays will be duplicates of the actual arrays
    # stored internally, so you cannot modify patterns in place.

    def all_patterns
      @mutex.synchronize do
        @patterns.keys.map{ |a_| a_.dup }
      end
    end


    # Returns an array of all object types known by this configuration.
    #
    # Does not include any "anonymous" types that are automatically
    # generated if you add a pattern without a type.

    def all_types
      @mutex.synchronize do
        @types.keys.find_all{ |t_| !t_.is_a?(AnonymousType) }
      end
    end


    # Returns an array of all category types known by this configuration.

    def all_categories
      @mutex.synchronize do
        @categories.keys
      end
    end


    # Returns an array of all convenience method names known by this
    # configuration.

    def all_convenience_methods
      @mutex.synchronize do
        @methods.keys
      end
    end


    # Returns true if this configuration includes the given pattern.

    def has_pattern?(pattern_)
      @mutex.synchronize do
        @patterns.has_key?(pattern_)
      end
    end


    # Returns true if this configuration includes the given object type.

    def has_type?(type_)
      @mutex.synchronize do
        @types.has_key?(type_)
      end
    end


    # Returns true if this configuration includes the given category type.

    def has_category?(category_)
      @mutex.synchronize do
        @categories.has_key?(category_)
      end
    end


    # Returns true if this configuration includes the given convenience method.

    def has_convenience_method?(method_)
      @mutex.synchronize do
        @methods.has_key?(method_)
      end
    end


    # Returns the object type corresponding to the given pattern.
    # Returns nil if the given pattern is not recognized.

    def type_for_pattern(pattern_)
      @mutex.synchronize do
        patdata_ = @patterns[pattern_]
        patdata_ ? patdata_[0] : nil
      end
    end


    # Returns an array of patterns corresponding to the given object type.
    # Returns the empty array if the given object type is not recognized.

    def patterns_for_type(type_)
      @mutex.synchronize do
        typedata_ = @types[type_]
        typedata_ ? typedata_.dup : []
      end
    end


    # Add a pattern to the configuration.
    #
    # You may use one of the following call sequences:
    #
    # [<tt>add_pattern( <i>pattern</i> ) { ... }</tt>]
    #   Add a simple pattern, using the given block to generate objects
    #   matching that pattern.
    #
    # [<tt>add_pattern( <i>pattern</i>, <i>to_generate_object</i> )</tt>]
    #   Add a simple pattern, using the given proc to generate objects
    #   matching that pattern.
    #
    # [<tt>add_pattern( <i>pattern</i>, <i>to_generate_object</i>, <i>to_generate_tuple</i> )</tt>]
    #   Add a simple pattern, using the given proc to generate objects
    #   matching that pattern, and to generate a tuple from an object.
    #
    # [<tt>add_pattern( <i>pattern</i>, <i>type</i>, <i>to_generate_object</i>, <i>to_generate_tuple</i> )</tt>]
    #   Add a pattern for the given type. You should provide both a proc
    #   to generate objects, and a proc to generate a tuple from an object.
    #
    # [<tt>add_pattern() { ... }</tt>]
    #   Utilize a PatternAdder DSL to define the pattern.

    def add_pattern(*args_, &block_)
      raise ConfigurationLockedError if @locked
      if block_
        case args_.size
        when 0
          adder_ = PatternAdder._new(nil, nil, nil, nil)
          ::Blockenspiel.invoke(block_, adder_)
        when 1
          adder_ = PatternAdder._new(args_[0], nil, block_, nil)
        else
          raise IllegalConfigurationError, "Did not recognize call sequence for add_pattern"
        end
      else
        case args_.size
        when 2, 3
          adder_ = PatternAdder._new(args_[0], nil, args_[1], args_[2])
        when 4
          adder_ = PatternAdder._new(args_[0], args_[1], args_[2], args_[3])
        else
          raise IllegalConfigurationError, "Did not recognize call sequence for add_pattern"
        end
      end
      pattern_ = adder_.pattern
      type_ = adder_.type || AnonymousType.new
      gen_obj_ = adder_.to_generate_object
      gen_tuple_ = adder_.to_generate_tuple
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        if @patterns.has_key?(pattern_)
          raise IllegalConfigurationError, "Pattern already exists"
        end
        @patterns[pattern_] = [type_, gen_obj_, gen_tuple_]
        (@types[type_] ||= []) << pattern_
      end
      self
    end


    # Remove the given pattern from this configuration.
    # Automatically removes the object type if this is the object type's
    # only remaining pattern.

    def delete_pattern(pattern_)
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        if (patdata_ = @patterns.delete(pattern_))
          type_ = patdata_[0]
          typedata_ = @types[type_]
          typedata_.delete(pattern_)
          @types.delete(type_) if typedata_.empty?
        end
      end
      self
    end


    # Remove the given object type from this configuration.
    # Automatically removes all patterns associated with this object type.

    def delete_type(type_)
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        if (typedata_ = @types.delete(type_))
          typedata_.each{ |pat_| @patterns.delete(pat_) }
        end
      end
      self
    end


    # Add a category type.
    #
    # You must provide a category type name, a pattern that recognizes
    # tuples that should trigger this category, and an array of indexes
    # into the pattern that indicates which tuple element(s) will
    # identify individual categories within this category type.

    def add_category(category_, pattern_, indexes_)
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        if @categories.has_key?(category_)
          raise IllegalConfigurationError, "Category already exists"
        end
        @categories[category_] = [pattern_, indexes_]
      end
      self
    end


    # Remove a category type by name.

    def delete_category(category_)
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        @categories.delete(category_)
      end
      self
    end


    # Add a convenience method, providing a short cut for doing lookups
    # in the registry. You must provide a pattern that serves as a tuple
    # template, and an array of indexes. The method will take a number of
    # arguments corresponding to that array, and the indexes will then be
    # used as indexes into the pattern, replacing pattern elements to
    # generate the actual tuple to be looked up.

    def add_convenience_method(name_, pattern_, indexes_)
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        name_ = name_.to_sym
        if @methods.has_key?(name_)
          raise IllegalConfigurationError, "Factory method already exists"
        end
        @methods[name_] = [pattern_, indexes_]
      end
      self
    end


    # Delete a convenience method by name.

    def delete_convenience_method(name_)
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        @methods.delete(name_.to_sym)
      end
      self
    end


    # Clear all configuration information, including all object types,
    # patterns, categories, and convenience methods.

    def clear
      @mutex.synchronize do
        raise ConfigurationLockedError if @locked
        @patterns.clear
        @types.clear
        @categories.clear
        @methods.clear
      end
      self
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
      if block_
        @gen_obj = block_
      else
        @gen_obj
      end
    end


    # Provide a block to call to generate the tuple corresponding to an
    # object. The repository calls this block when an object is added, in
    # order to generate the appropriate tuples for looking up the object.

    def to_generate_tuple(&block_)
      if block_
        @gen_tuple = block_
      else
        @gen_tuple
      end
    end


    class << self

      # :stopdoc:
      alias_method :_new, :new
      private :new
      # :startdoc:

    end


  end


end
