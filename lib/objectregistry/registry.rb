# -----------------------------------------------------------------------------
#
# ObjectRegistry registry object
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


module ObjectRegistry


  # A registry object.

  class Registry


    def initialize(patterns_, types_, categories_)  # :nodoc:
      @patterns = patterns_
      @types = types_
      @categories = categories_
      @tuples = {}
      @objects = {}
      @config = Configuration._new(self, @patterns, @types, @categories)
    end


    def inspect  # :nodoc:
      "#<#{self.class}:0x#{object_id.to_s(16)}>"
    end


    # Get the configuration for this registry

    def configuration
      @config
    end


    # Clear out all cached objects from the registry.

    def clear
      @tuples.clear
      @objects.clear
      @categories.each{ |k_, v_| v_[2].clear }
    end


    # Return the number of objects cached in the registry.

    def size
      @objects.size
    end


    # Get the object corresponding to the given tuple.
    # If the tuple is not present, the registry tries to generate the
    # object for you. Returns nil if it is unable to do so.
    # The optional args parameter is passed to the object generator.

    def lookup(tuple_, args_={})
      @config.lock
      if (objdata_ = @tuples[tuple_])
        return objdata_[0]
      end
      @patterns.each do |pattern_, patdata_|
        if Utils.matches?(pattern_, tuple_)
          block_ = patdata_[1]
          if block_
            obj_ = case block_.arity
              when 0 then block_.call
              when 1 then block_.call(tuple_)
              when 2 then block_.call(tuple_, self)
              else block_.call(tuple_, self, args_)
            end
            unless obj_.nil?
              type_ = patdata_[0]
              objdata_ = [obj_, type_, {}]
              @objects[obj_.object_id] = objdata_
              if type_
                tuple_list_ = @types[type_].map do |pat_|
                  block_ = @patterns[pat_][2]
                  block_ ? block_.call(obj_) : nil
                end
              else
                tuple_list_ = [tuple_]
              end
              tuple_list_.each do |tup_|
                _add_tuple(objdata_, tup_) if tup_
              end
              return obj_
            end
          end
        end
      end
      return nil
    end


    # Add the given object to the registry. You must specify the type of
    # object, which is used to determine what tuples correspond to it.

    def add(type_, object_)
      @config.lock
      return false if object_.nil? || @objects.has_key?(object_.object_id)
      objdata_ = [object_, type_, {}]
      @objects[object_.object_id] = objdata_
      @types[type_].each do |pat_|
        block_ = @patterns[pat_][2]
        tup_ = block_ ? block_.call(object_) : nil
        _add_tuple(objdata_, tup_) if tup_
      end
      true
    end


    # Retrieve the cached object corresponding to the given tuple. Returns
    # nil if the object is not currently cached. Does not attempt to
    # generate the object for you.

    def get(tuple_)
      objdata_ = @tuples[tuple_]
      objdata_ ? objdata_[0] : nil
    end


    # Returns an array of tuples corresponding to the given object.
    # Returns nil if the given object is not cached in the registry.

    def tuples_for(object_)
      objdata_ = @objects[object_.object_id]
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


    # Delete the given object.
    #
    # If you pass an Array, it is interpreted as a tuple.
    # If you pass something other than an Array or a Hash, it is
    # interpreted as an object.
    # Otherwise, you can explicitly specify whether you are passing
    # a tuple or object by using hash named arguments, e.g.
    # <tt>:tuple =&gt;</tt>, or <tt>:object =&gt;</tt>.

    def delete(arg_)
      objdata_ = _get_objdata(arg_)
      if objdata_
        @objects.delete(objdata_[0].object_id)
        objdata_[2].each_key{ |tup_| _remove_tuple(objdata_, tup_) }
        return objdata_[0]
      else
        return nil
      end
    end


    # Delete all objects with a tuple matching the given pattern.

    def delete_pattern(pattern_)
      tuples_ = @tuples.keys.find_all{ |tuple_| Utils.matches?(pattern_, tuple_) }
      tuples_.each{ |tuple_| delete(tuple_) }
      tuples_.size
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
      objdata_ = _get_objdata(arg_)
      return nil unless objdata_
      obj_ = objdata_[0]
      tuple_hash_ = objdata_[2]
      type_ = objdata_[1]
      return obj_ unless type_
      new_tuple_list_ = @types[type_].map do |pat_|
        block_ = @patterns[pat_][2]
        block_ ? block_.call(obj_) : nil
      end
      new_tuple_list_.compact!
      new_tuple_list_.each do |tup_|
        _add_tuple(objdata_, tup_) unless tuple_hash_.has_key?(tup_)
      end
      (tuple_hash_.keys - new_tuple_list_).each do |tup_|
        _remove_tuple(objdata_, tup_)
      end
      obj_
    end


    def categories(arg_)
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


    def objects_in_category(category_, index_)
      catdata_ = @categories[category_]
      return nil unless catdata_
      tuple_hash_ = catdata_[2][index_]
      tuple_hash_ ? tuple_hash_.values.map{ |objdata_| objdata_[0] } : []
    end


    def tuples_in_category(category_, index_)
      catdata_ = @categories[category_]
      return nil unless catdata_
      tuple_hash_ = catdata_[2][index_]
      tuple_hash_ ? tuple_hash_.keys : []
    end


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


    def _add_tuple(objdata_, tuple_)  # :nodoc:
      return false if @tuples.has_key?(tuple_)
      @tuples[tuple_] = objdata_
      tupcats_ = []
      @categories.each do |category_, catdata_|
        if Utils.matches?(catdata_[0], tuple_)
          index_ = catdata_[1].map{ |i_| tuple_[i_] }
          (catdata_[2][index_] ||= {})[tuple_] = objdata_
          tupcats_ << category_
        end
      end
      objdata_[2][tuple_] = tupcats_
      true
    end
    private :_add_tuple


    def _remove_tuple(objdata_, tuple_)  # :nodoc:
      tupcats_ = objdata_[2][tuple_]
      return false unless tupcats_
      @tuples.delete(tuple_)
      tupcats_.each do |cat_|
        catdata_ = @categories[cat_]
        index_ = catdata_[1].map{ |i_| tuple_[i_] }
        catdata_[2][index_].delete(tuple_)
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

    def create
      Registry._new({}, {}, {})
    end


  end


end
