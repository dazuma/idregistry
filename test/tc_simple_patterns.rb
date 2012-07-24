# -----------------------------------------------------------------------------
#
# Basic end-to-end tests
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


require 'test/unit'
require 'idregistry'
require 'set'


module IDRegistry
  module Tests  # :nodoc:

    class TestSimplePatterns < ::Test::Unit::TestCase  # :nodoc:


      Class1 = ::Struct.new(:value)


      def setup
        @registry = IDRegistry.create
        @registry.config do
          add_pattern do
            pattern [:hello, ::Integer]
            type :hello_numbers
            to_generate_object{ |tuple_| Class1.new(tuple_[1]) }
            to_generate_tuple{ |obj_| [:hello, obj_.value] }
          end
          add_pattern do
            pattern [:hello, ::Float]
            type :hello_numbers
            to_generate_object{ |tuple_| Class1.new(tuple_[1].to_i) }
            to_generate_tuple{ |obj_| [:hello, obj_.value.to_f] }
          end
          add_pattern do
            pattern [:world, ::Float]
            type :world_numbers
            to_generate_object{ |tuple_| Class1.new(tuple_[1].to_i) }
            to_generate_tuple{ |obj_| [:world, obj_.value.to_f] }
          end
        end
      end


      def test_simple_lookup_object
        obj_ = @registry.lookup([:hello, 1])
        assert_equal(Class1.new(1), obj_)
      end


      def test_lookup_with_bad_pattern
        assert_nil(@registry.lookup([:yoyo, 1]))
      end


      def test_simple_lookup_size
        assert_equal(0, @registry.size)
        @registry.lookup([:hello, 1])
        assert_equal(1, @registry.size)
      end


      def test_simple_lookup_and_get
        assert_nil(@registry.get([:hello, 1]))
        obj_ = @registry.lookup([:hello, 1])
        assert_equal(obj_.object_id, @registry.get([:hello, 1]).object_id)
      end


      def test_simple_lookup_and_tuples_for
        obj_ = @registry.lookup([:hello, 1])
        assert_nil(@registry.tuples_for(Class1.new(1)))
        assert_equal(::Set.new([[:hello, 1], [:hello, 1.0]]), ::Set.new(@registry.tuples_for(obj_)))
      end


      def test_simple_lookup_and_include
        obj_ = @registry.lookup([:hello, 1])
        assert_equal(false, @registry.include?(Class1.new(1)))
        assert_equal(true, @registry.include?(obj_))
        assert_equal(true, @registry.include?([:hello, 1]))
        assert_equal(true, @registry.include?([:hello, 1.0]))
        assert_equal(false, @registry.include?([:world, 1.0]))
      end


      def test_simple_lookup_returns_same_object
        obj1_ = @registry.lookup([:hello, 1])
        obj2_ = @registry.lookup([:hello, 1.0])
        assert_equal(obj1_.object_id, obj2_.object_id)
        assert_equal(1, @registry.size)
      end


      def test_multiple_lookups
        obj1_ = @registry.lookup([:hello, 1])
        obj2_ = @registry.lookup([:hello, 2.0])
        assert_not_equal(obj1_.object_id, obj2_.object_id)
        assert_equal(2, @registry.size)
      end


      def test_add_for_one_tuple
        obj_ = Class1.new(1)
        @registry.add(:world_numbers, obj_)
        assert_equal(1, @registry.size)
        assert_equal(obj_.object_id, @registry.get([:world, 1.0]).object_id)
        assert_equal([[:world, 1.0]], @registry.tuples_for(obj_))
      end


      def test_add_for_multi_tuples
        obj_ = Class1.new(1)
        @registry.add(:hello_numbers, obj_)
        assert_equal(1, @registry.size)
        assert_equal(obj_.object_id, @registry.get([:hello, 1.0]).object_id)
        assert_equal(::Set.new([[:hello, 1], [:hello, 1.0]]), ::Set.new(@registry.tuples_for(obj_)))
      end


      def test_delete_object
        obj_ = @registry.lookup([:hello, 1])
        @registry.delete(obj_)
        assert_nil(@registry.get([:hello, 1]))
        assert_equal(0, @registry.size)
      end


      def test_delete_tuple
        @registry.lookup([:hello, 1])
        @registry.delete([:hello, 1.0])
        assert_nil(@registry.get([:hello, 1]))
        assert_equal(0, @registry.size)
      end


      def test_rekey_single_tuple_by_object
        obj_ = @registry.lookup([:world, 1.0])
        obj_.value = 2
        @registry.rekey(obj_)
        assert_nil(@registry.get([:world, 1.0]))
        assert_equal(obj_.object_id, @registry.get([:world, 2.0]).object_id)
        assert_equal([[:world, 2.0]], @registry.tuples_for(obj_))
      end


      def test_rekey_single_tuple_by_tuple
        obj_ = @registry.lookup([:world, 1.0])
        obj_.value = 2
        @registry.rekey([:world, 1.0])
        assert_nil(@registry.get([:world, 1.0]))
        assert_equal(obj_.object_id, @registry.get([:world, 2.0]).object_id)
        assert_equal([[:world, 2.0]], @registry.tuples_for(obj_))
      end


      def test_rekey_multi_tuple_by_object
        obj_ = @registry.lookup([:hello, 1.0])
        obj_.value = 2
        @registry.rekey(obj_)
        assert_nil(@registry.get([:hello, 1.0]))
        assert_equal(obj_.object_id, @registry.get([:hello, 2]).object_id)
        assert_equal(::Set.new([[:hello, 2], [:hello, 2.0]]), ::Set.new(@registry.tuples_for(obj_)))
      end


      def test_rekey_multi_tuple_by_tuple
        obj_ = @registry.lookup([:hello, 1.0])
        obj_.value = 2
        @registry.rekey([:hello, 1])
        assert_nil(@registry.get([:hello, 1.0]))
        assert_equal(obj_.object_id, @registry.get([:hello, 2]).object_id)
        assert_equal(::Set.new([[:hello, 2], [:hello, 2.0]]), ::Set.new(@registry.tuples_for(obj_)))
      end


    end

  end
end
