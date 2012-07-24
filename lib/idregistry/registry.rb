# -----------------------------------------------------------------------------
#
# IDRegistry registry object
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


module IDRegistry


  # A registry object.

  class Registry


    def initialize(patterns_, types_, categories_, methods_)  # :nodoc:
      @patterns = patterns_
      @types = types_
      @categories = categories_
      @methods = methods_
      @tuples = {}
      @objects = {}
      @catdata = {}
      @config = Configuration._new(self, @patterns, @types, @categories, @methods)
      @mutex = ::Mutex.new
    end


    def inspect  # :nodoc:
      "#<#{self.class}:0x#{object_id.to_s(16)} size=#{size}>"
    end


    # Get the configuration for this registry.
    #
    # You may also configure this registry by providing a block.
    # The configuration object will then be available as a DSL.

    def config(&block_)
      ::Blockenspiel.invoke(block_, @config) if block_
      @config
    end


    # Return the number of objects cached in the registry.

    def size
      @objects.size
    end


    # Retrieve the cached object corresponding to the given tuple. Returns
    # nil if the object is not currently cached. Does not attempt to
    # generate the object for you.

    def get(tuple_)
      objdata_ = @tuples[tuple_]
      objdata_ ? objdata_[0] : nil
    end


    # Returns an array of all tuples corresponding to the given object,
    # or the object identified by the given tuple.
    # Returns nil if the given object is not cached in the registry.
    #
    # If you pass an Array, it is interpreted as a tuple.
    # If you pass something other than an Array or a Hash, it is
    # interpreted as an object.
    # Otherwise, you can explicitly specify whether you are passing
    # a tuple or object by using hash named arguments, e.g.
    # <tt>:tuple =&gt;</tt>, or <tt>:object =&gt;</tt>.

    def tuples_for(arg_)
      objdata_ = _get_objdata(arg_)
      objdata_ ? objdata_[2].keys : nil
    end


    # Returns true if the given object or tuple is present.
    #
    # If you pass an Array, it is interpreted as a tuple.
    # If you pass something other than an Array or a Hash, it is
    # interpreted as an object.
    # Otherwise, you can explicitly specify whether you are passing
    # a tuple or object by using hash named arguments, e.g.
    # <tt>:tuple =&gt;</tt>, or <tt>:object =&gt;</tt>.

    def include?(arg_)
      _get_objdata(arg_) ? true : false
    end


    # Return all the categories for the given object or tuple.
    #
    # If you pass an Array, it is interpreted as a tuple.
    # If you pass something other than an Array or a Hash, it is
    # interpreted as an object.
    # Otherwise, you can explicitly specify whether you are passing
    # a tuple or object by using hash named arguments, e.g.
    # <tt>:tuple =&gt;</tt>, or <tt>:object =&gt;</tt>.
    #
    # The return value is a hash. The keys are the category types
    # relevant to this object. The values are the index arrays
    # indicating which category the object falls under for each type.

    def categories(arg_)
      @config.lock

      objdata_ = _get_objdata(arg_)
      return nil unless objdata_
      hash_ = {}
      objdata_[2].each do |tup_, tupcats_|
        tupcats_.each do |cat_|
          hash_[cat_] = @categories[cat_][1].map{ |elem_| tup_[elem_] }
        end
      end
      hash_
    end


    # Return all objects in a given category, which is specified by the
    # category type and the index array indicating which category of that
    # type.

    def objects_in_category(category_, index_)
      @config.lock

      return nil unless @categories.include?(category_)
      tuple_hash_ = (@catdata[category_] ||= {})[index_]
      tuple_hash_ ? tuple_hash_.values.map{ |objdata_| objdata_[0] } : []
    end


    # Return all tuples in a given category, which is specified by the
    # category type and the index array indicating which category of that
    # type.

    def tuples_in_category(category_, index_)
      @config.lock

      return nil unless @categories.include?(category_)
      tuple_hash_ = (@catdata[category_] ||= {})[index_]
      tuple_hash_ ? tuple_hash_.keys : []
    end


    # Get the object corresponding to the given tuple.
    # If the tuple is not present, the registry tries to generate the
    # object for you. Returns nil if it is unable to do so.
    #
    # You may pass the tuple as a single array argument, or as a set
    # of arguments.
    #
    # If the last argument is a hash, it is removed from the tuple and
    # treated as an options hash that may be passed to an object
    # generator block.

    def lookup(*args_)
      opts_ = args_.last.is_a?(::Hash) ? args_.pop : {}
      tuple_ = args_.size == 1 && args_.first.is_a?(::Array) ? args_.first : args_

      @config.lock

      # Fast-track lookup if it's already there
      if (objdata_ = @tuples[tuple_])
        return objdata_[0]
      end

      # Not there for now. Try to create the object.
      # We want to do this before entering the synchronize block because
      # we don't want callbacks called within the synchronization.
      obj_ = nil
      type_ = nil
      @patterns.each do |pattern_, patdata_|
        if Utils.matches?(pattern_, tuple_)
          block_ = patdata_[1]
          obj_ = case block_.arity
            when 0 then block_.call
            when 1 then block_.call(tuple_)
            when 2 then block_.call(tuple_, self)
            else block_.call(tuple_, self, opts_)
          end
          unless obj_.nil?
            type_ = patdata_[0]
            break
          end
        end
      end

      if obj_
        # Now attempt to insert the object.
        # This part is synchronized to protect against concurrent mutation.
        # Once in the synchronize block, we also double-check that no other
        # thread added the object in the meantime. If another thread did,
        # we throw away the object we just created, and return the other
        # thread's object instead.
        @mutex.synchronize do
          if (objdata_ = @tuples[tuple_])
            obj_ = objdata_[0]
          else
            _internal_add(type_, obj_)
          end
        end
      end
      obj_
    end


    # Add the given object to the registry. You must specify the type of
    # object, which is used to determine what tuples correspond to it.

    def add(type_, object_)
      @config.lock

      # Some sanity checks of the arguments.
      if object_.nil?
        raise ObjectKeyError, "Attempt to add a nil object"
      end
      unless @types.has_key?(type_)
        raise ObjectKeyError, "Unrecognized type: #{type_}"
      end

      # Synchronize the actual add to protect against concurrent mutation.
      @mutex.synchronize do
        _internal_add(type_, object_)
      end
      self
    end


    # Delete the given object.
    #
    # If you pass an Array, it is interpreted as a tuple.
    # If you pass something other than an Array or a Hash, it is
    # interpreted as an object.
    # Otherwise, you can explicitly specify whether you are passing
    # a tuple or object by using hash named arguments, e.g.
    # <tt>:tuple =&gt;</tt>, or <tt>:object =&gt;</tt>.

    def delete(arg_)
      @config.lock

      @mutex.synchronize do
        if (objdata_ = _get_objdata(arg_))
          @objects.delete(objdata_[0].object_id)
          objdata_[2].each_key{ |tup_| _remove_tuple(objdata_, tup_) }
        end
      end
      self
    end


    # Delete all objects with a tuple matching the given pattern.

    def delete_pattern(pattern_)
      @config.lock

      @mutex.synchronize do
        tuples_ = @tuples.keys.find_all{ |tuple_| Utils.matches?(pattern_, tuple_) }
        tuples_.each do |tuple_|
          objdata_ = @tuples[tuple_]
          @objects.delete(objdata_[0].object_id)
          objdata_[2].each_key{ |tup_| _remove_tuple(objdata_, tup_) }
        end
      end
      self
    end


    # Recompute the tuples for the given object, which may be identified
    # by object or tuple. Call this when the value of the object changes
    # in such a way that the registry should identify it differently.
    #
    # If you pass an Array, it is interpreted as a tuple.
    # If you pass something other than an Array or a Hash, it is
    # interpreted as an object.
    # Otherwise, you can explicitly specify whether you are passing
    # a tuple or object by using hash named arguments, e.g.
    # <tt>:tuple =&gt;</tt>, or <tt>:object =&gt;</tt>.

    def rekey(arg_)
      @config.lock

      # Resolve the object.
      if (objdata_ = _get_objdata(arg_))

        # Look up tuple generators from the type, and determine the
        # new tuples for the object.
        # Do this before entering the synchronize block because we
        # don't want callbacks called within the synchronization.
        obj_ = objdata_[0]
        type_ = objdata_[1]
        new_tuple_list_ = []
        @types[type_].each do |pat_|
          if (block_ = @patterns[pat_][2])
            new_tuple_ = block_.call(obj_)
            new_tuple_list_ << new_tuple_ if new_tuple_
          else
            raise ObjectKeyError, "Not all patterns for this type can generate tuples"
          end
        end

        # Synchronize to protect against concurrent mutation.
        @mutex.synchronize do
          # One last check to ensure the object is still present
          if @objects.has_key?(obj_.object_id)
            # Ensure none of the new tuples isn't pointed elsewhere already.
            # Tuples pointed at this object, ignore them.
            # Tuples pointed at another object, raise an error.
            tuple_hash_ = objdata_[2]
            new_tuple_list_.delete_if do |tup_|
              if tuple_hash_.has_key?(tup_)
                true
              elsif @tuples.has_key?(tup_)
                raise ObjectKeyError, "Could not rekey because one of the new tuples is already present"
              else
                false
              end
            end
            # Now go through and edit the tuples
            (tuple_hash_.keys - new_tuple_list_).each do |tup_|
              _remove_tuple(objdata_, tup_)
            end
            new_tuple_list_.each do |tup_|
              _add_tuple(objdata_, tup_)
            end
          end
        end
      end
      self
    end


    # Clear out all cached objects from the registry.

    def clear
      @mutex.synchronize do
        @tuples.clear
        @objects.clear
        @catdata.clear
      end
      self
    end


    # Implement convenience methods.

    def method_missing(name_, *args_)  # :nodoc:
      if (method_info_ = @methods[name_])
        tuple_ = method_info_[0].dup
        indexes_ = method_info_[1]
        case indexes_
        when ::Array
          lookup_args_ = args_.size == indexes_.size + 1 ? args_.pop : {}
          if lookup_args_.is_a?(::Hash) && args_.size == indexes_.size
            args_.each_with_index do |a_, i_|
              if (j_ = indexes_[i_])
                tuple_[j_] = a_
              end
            end
            return lookup(tuple_, lookup_args_)
          end
        when ::Hash
          lookup_args_ = args_.size == 2 ? args_.pop : {}
          if lookup_args_.is_a?(::Hash) && args_.size == 1
            arg_ = args_[0]
            if arg_.is_a?(::Hash)
              arg_.each do |k_, v_|
                if (j_ = indexes_[k_])
                  tuple_[j_] = v_
                end
              end
              return lookup(tuple_, lookup_args_)
            end
          end
        end
      end
      super
    end


    # Internal method that gets an object data array given an object
    # specification.

    def _get_objdata(arg_)  # :nodoc:
      case arg_
      when ::Array
        @tuples[arg_]
      when ::Hash
        if (tuple_ = arg_[:tuple])
          @tuples[tuple_]
        elsif (obj_ = arg_[:object])
          @objects[obj_.object_id]
        else
          nil
        end
      else
        @objects[arg_.object_id]
      end
    end
    private :_get_objdata


    # Internal add method.
    # This needs to be called within synchronization.

    def _internal_add(type_, obj_)  # :nodoc:
      # Check if this object is present already.
      if (objdata_ = @objects[obj_.object_id])
        # The object is present already. If it has the right type,
        # then just return the object and don't regenerate tuples.
        # If it has the wrong type, give up.
        if objdata_[1] != type_
          raise ObjectKeyError, "Object is already present with type #{objdata_[1]}"
        end
        true
      else
        # Object is not present.
        # Generate list of tuples to add, and make sure they are unique.
        tuple_list_ = []
        @types[type_].map do |pat_|
          if (block_ = @patterns[pat_][2])
            if (tup_ = block_.call(obj_))
              if @tuples.has_key?(tup_)
                raise ObjectKeyError, "New object wants to overwrite an existing tuple: #{tup_.inspect}"
              end
              tuple_list_ << tup_
            end
          end
        end
        return false if tuple_list_.size == 0

        # Insert the object. This is the actual mutation.
        objdata_ = [obj_, type_, {}]
        @objects[obj_.object_id] = objdata_
        tuple_list_.each do |tup_|
          _add_tuple(objdata_, tup_) if tup_
        end
        true
      end
    end
    private :_internal_add


    # This needs to be called within synchronization.

    def _add_tuple(objdata_, tuple_)  # :nodoc:
      return false if @tuples.has_key?(tuple_)
      @tuples[tuple_] = objdata_
      tupcats_ = []
      @categories.each do |category_, catdata_|
        if Utils.matches?(catdata_[0], tuple_)
          index_ = catdata_[1].map{ |i_| tuple_[i_] }
          ((@catdata[category_] ||= {})[index_] ||= {})[tuple_] = objdata_
          tupcats_ << category_
        end
      end
      objdata_[2][tuple_] = tupcats_
      true
    end
    private :_add_tuple


    # This needs to be called within synchronization.

    def _remove_tuple(objdata_, tuple_)  # :nodoc:
      tupcats_ = objdata_[2][tuple_]
      return false unless tupcats_
      @tuples.delete(tuple_)
      tupcats_.each do |cat_|
        index_ = @categories[cat_][1].map{ |i_| tuple_[i_] }
        @catdata[cat_][index_].delete(tuple_)
      end
      objdata_[2].delete(tuple_)
      true
    end
    private :_remove_tuple


    class << self

      # :stopdoc:
      alias_method :_new, :new
      private :new
      # :startdoc:

    end


  end


  class << self


    # Create a new, empty registry with an empty configuration.
    #
    # If you pass a block, it will be used to configure the registry,
    # as if you had passed it to the config method.

    def create(&block_)
      reg_ = Registry._new({}, {}, {}, {})
      reg_.config(&block_) if block_
      reg_
    end


  end


end
