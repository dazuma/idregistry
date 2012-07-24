# -----------------------------------------------------------------------------
#
# Category tests
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

    class TestCategories < ::Test::Unit::TestCase  # :nodoc:


      Class1 = ::Struct.new(:value)
      Class2 = ::Struct.new(:value1, :value2)


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
            pattern [:world, ::Float, ::String]
            type :world_numbers
            to_generate_object{ |tuple_| Class2.new(tuple_[1].to_f, tuple_[2].to_s) }
            to_generate_tuple{ |obj_| [:world, obj_.value1.to_f, obj_.value2.to_s] }
          end
          add_category(:world_float, [:world, ::Float, ::String], [1])
          add_category(:world_string, [:world, ::Float, ::String], [2])
          add_category(:world_both, [:world, ::Float, ::String], [1, 2])
        end
      end


      def test_categories_for_simple_object
        obj1_ = @registry.lookup(:world, 1.0, 'hello')
        assert_equal({:world_float => [1.0], :world_string => ['hello'], :world_both => [1.0, 'hello']},
          @registry.categories(obj1_))
      end


      def test_objects_in_category_1_index
        obj1_ = @registry.lookup(:world, 1.0, 'hello')
        obj2_ = @registry.lookup(:world, 2.0, 'hello')
        @registry.lookup(:world, 2.0, 'bye')
        @registry.lookup(:hello, 4)
        assert_equal(::Set.new([obj1_, obj2_]),
          ::Set.new(@registry.objects_in_category(:world_string, ['hello'])))
      end


      def test_tuples_in_category_1_index
        @registry.lookup(:world, 1.0, 'hello')
        @registry.lookup(:world, 2.0, 'hello')
        @registry.lookup(:world, 2.0, 'bye')
        @registry.lookup(:hello, 4)
        assert_equal(::Set.new([[:world, 1.0, 'hello'], [:world, 2.0, 'hello']]),
          ::Set.new(@registry.tuples_in_category(:world_string, ['hello'])))
      end


      def test_objects_in_category_2_index
        @registry.lookup(:world, 1.0, 'hello')
        obj2_ = @registry.lookup(:world, 2.0, 'hello')
        @registry.lookup(:world, 2.0, 'bye')
        @registry.lookup(:hello, 4)
        assert_equal([obj2_],
          @registry.objects_in_category(:world_both, [2.0, 'hello']))
      end


      def test_tuples_in_category_2_index
        @registry.lookup(:world, 1.0, 'hello')
        @registry.lookup(:world, 2.0, 'hello')
        @registry.lookup(:world, 2.0, 'bye')
        @registry.lookup(:hello, 4)
        assert_equal([[:world, 2.0, 'hello']],
          @registry.tuples_in_category(:world_both, [2.0, 'hello']))
      end


      def test_category_updated_through_rekey
        obj_ = @registry.lookup(:world, 1.0, 'hello')
        obj_.value1 = 2.0
        @registry.rekey(obj_)
        assert_equal({:world_float => [2.0], :world_string => ['hello'], :world_both => [2.0, 'hello']},
          @registry.categories(obj_))
      end


      def test_delete_category
        obj1_ = @registry.lookup(:world, 1.0, 'hello')
        obj2_ = @registry.lookup(:world, 2.0, 'hello')
        obj3_ = @registry.lookup(:world, 2.0, 'bye')
        obj4_ = @registry.lookup(:hello, 4)
        @registry.delete_category(:world_string, ['hello'])
        assert_equal(2, @registry.size)
        assert_equal(false, @registry.include?(obj1_))
        assert_equal(false, @registry.include?(obj2_))
        assert_equal(true, @registry.include?(obj3_))
        assert_equal(true, @registry.include?(obj4_))
      end


    end

  end
end
