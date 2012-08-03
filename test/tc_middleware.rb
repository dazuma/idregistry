# -----------------------------------------------------------------------------
#
# Tests for Rack middleware
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


module IDRegistry
  module Tests  # :nodoc:

    class TestMiddleware < ::Test::Unit::TestCase  # :nodoc:


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


      def test_clear_registry_task_without_condition
        task_ = RegistryMiddleware::ClearRegistry.new(@registry)
        @registry.lookup(:hello, 1)
        assert_equal(1, @registry.size)
        task_.pre({})
        assert_equal(1, @registry.size)
        task_.post({})
        assert_equal(0, @registry.size)
      end


      def test_clear_registry_task_with_condition
        task_ = RegistryMiddleware::ClearRegistry.new(@registry) do |env_|
          env_[:foo] == :bar
        end
        @registry.lookup(:hello, 1)
        assert_equal(1, @registry.size)
        task_.pre({:foo => :baz})
        task_.post({:foo => :baz})
        assert_equal(1, @registry.size)
        task_.pre({:foo => :bar})
        task_.post({:foo => :bar})
        assert_equal(0, @registry.size)
      end


      def test_clear_registry_task_before_request
        task_ = RegistryMiddleware::ClearRegistry.new(@registry, :before_request => true)
        @registry.lookup(:hello, 1)
        assert_equal(1, @registry.size)
        task_.pre({})
        assert_equal(0, @registry.size)
        task_.post({})
        assert_equal(0, @registry.size)
      end


      def test_spawn_registry_task
        task_ = RegistryMiddleware::SpawnRegistry.new(@registry.config.lock, :reg)
        obj1_ = @registry.lookup(:hello, 1)
        assert_equal(1, @registry.size)
        env_ = {}
        task_.pre(env_)
        nreg_ = env_[:reg]
        assert_equal(0, nreg_.size)
        obj2_ = nreg_.lookup(:hello, 1)
        assert_not_nil(obj2_)
        assert_not_equal(obj1_.object_id, obj2_.object_id)
        task_.post(env_)
        assert_nil(env_[:reg])
        assert_equal(0, nreg_.size)
        assert_equal(1, @registry.size)
      end


      def test_full_middleware
        called_ = false
        task_ = RegistryMiddleware::ClearRegistry.new(@registry)
        app_ = ::Proc.new do |env_|
          @registry.lookup(:hello, 2)
          assert_equal(2, @registry.size)
          called_ = true
          nil
        end
        middleware_ = RegistryMiddleware.new(app_, [task_])
        @registry.lookup(:hello, 1)
        assert_equal(1, @registry.size)
        middleware_.call({})
        assert_equal(true, called_)
        assert_equal(0, @registry.size)
      end


    end

  end
end
