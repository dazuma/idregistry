# -----------------------------------------------------------------------------
#
# Configuration tests
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

    class TestConfiguration < ::Test::Unit::TestCase  # :nodoc:


      Class1 = ::Struct.new(:value)
      Class2 = ::Struct.new(:value1, :value2)


      def setup
        @config = IDRegistry.create.config
      end


      def test_new_config_is_unlocked
        assert_equal(false, @config.locked?)
      end


      def test_empty_config
        assert_equal([], @config.all_patterns)
        assert_equal([], @config.all_types)
        assert_equal([], @config.all_categories)
        assert_equal(false, @config.has_pattern?([]))
        assert_equal(false, @config.has_type?(:type))
        assert_equal(false, @config.has_category?(:cat))
      end


      def test_add_pattern_and_list_patterns_and_types
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        assert_equal([[:hello, ::Integer]], @config.all_patterns)
        assert_equal([:hello_numbers], @config.all_types)
        assert_equal([], @config.all_categories)
        assert_equal(false, @config.has_pattern?([:bye, ::Integer]))
        assert_equal(true, @config.has_pattern?([:hello, ::Integer]))
        assert_equal(false, @config.has_type?(:hello_letters))
        assert_equal(true, @config.has_type?(:hello_numbers))
      end


      def test_type_for_pattern_with_one_pattern
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        assert_equal(:hello_numbers, @config.type_for_pattern([:hello, ::Integer]))
        assert_nil(@config.type_for_pattern([:bye, ::Integer]))
      end


      def test_patterns_for_type_with_one_pattern
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        assert_equal([[:hello, ::Integer]], @config.patterns_for_type(:hello_numbers))
        assert_equal([], @config.patterns_for_type(:hello_letters))
      end


      def test_list_patterns_and_types_with_two_patterns_for_the_same_type
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        assert_equal(::Set.new([[:hello, ::Integer], [:world, ::Float]]), ::Set.new(@config.all_patterns))
        assert_equal([:hello_numbers], @config.all_types)
        assert_equal([], @config.all_categories)
        assert_equal(true, @config.has_pattern?([:hello, ::Integer]))
        assert_equal(false, @config.has_pattern?([:world, ::Integer]))
        assert_equal(true, @config.has_pattern?([:world, ::Float]))
        assert_equal(true, @config.has_type?(:hello_numbers))
      end


      def test_type_for_pattern_with_two_patterns_for_the_same_type
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        assert_equal(:hello_numbers, @config.type_for_pattern([:hello, ::Integer]))
        assert_equal(:hello_numbers, @config.type_for_pattern([:world, ::Float]))
        assert_nil(@config.type_for_pattern([:world, ::Integer]))
      end


      def test_patterns_for_type_with_two_patterns_for_the_same_type
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        assert_equal(::Set.new([[:hello, ::Integer], [:world, ::Float]]), ::Set.new(@config.patterns_for_type(:hello_numbers)))
        assert_equal([], @config.patterns_for_type(:hello_letters))
      end


      def test_list_patterns_and_types_with_two_patterns_of_different_types
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        assert_equal(::Set.new([[:hello, ::Integer], [:world, ::Float]]), ::Set.new(@config.all_patterns))
        assert_equal(::Set.new([:hello_numbers, :world_numbers]), ::Set.new(@config.all_types))
        assert_equal([], @config.all_categories)
        assert_equal(true, @config.has_pattern?([:hello, ::Integer]))
        assert_equal(false, @config.has_pattern?([:world, ::Integer]))
        assert_equal(true, @config.has_pattern?([:world, ::Float]))
        assert_equal(true, @config.has_type?(:hello_numbers))
        assert_equal(true, @config.has_type?(:world_numbers))
      end


      def test_type_for_pattern_with_two_patterns_of_different_types
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        assert_equal(:hello_numbers, @config.type_for_pattern([:hello, ::Integer]))
        assert_equal(:world_numbers, @config.type_for_pattern([:world, ::Float]))
        assert_nil(@config.type_for_pattern([:world, ::Integer]))
      end


      def test_patterns_for_type_with_two_patterns_of_different_types
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        assert_equal([[:hello, ::Integer]], @config.patterns_for_type(:hello_numbers))
        assert_equal([[:world, ::Float]], @config.patterns_for_type(:world_numbers))
        assert_equal([], @config.patterns_for_type(:hello_letters))
      end


      def test_add_pattern_dsl
        @config.add_pattern do
          pattern([:hello, ::Integer])
          type(:hello_numbers)
          to_generate_object do |tuple_|
            Class1.new(tuple_[1])
          end
          to_generate_tuple do |obj_|
            [:hello, obj_.value]
          end
        end
        assert_equal([[:hello, ::Integer]], @config.all_patterns)
        assert_equal([:hello_numbers], @config.all_types)
        assert_equal(:hello_numbers, @config.type_for_pattern([:hello, ::Integer]))
        assert_equal([[:hello, ::Integer]], @config.patterns_for_type(:hello_numbers))
      end


      def test_delete_pattern
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:hello, ::Float], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:hello, obj_.value.to_f] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        @config.delete_pattern([:hello, ::Integer])
        assert_equal(::Set.new([[:hello, ::Float], [:world, ::Float]]), ::Set.new(@config.all_patterns))
        assert_equal(::Set.new([:hello_numbers, :world_numbers]), ::Set.new(@config.all_types))
        assert_nil(@config.type_for_pattern([:hello, ::Integer]))
        assert_equal([[:hello, ::Float]], @config.patterns_for_type(:hello_numbers))
      end


      def test_delete_pattern_which_deletes_type
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        @config.delete_pattern([:hello, ::Integer])
        assert_equal([[:world, ::Float]], @config.all_patterns)
        assert_equal([:world_numbers], @config.all_types)
        assert_nil(@config.type_for_pattern([:hello, ::Integer]))
        assert_equal([], @config.patterns_for_type(:hello_numbers))
      end


      def test_delete_type
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:hello, ::Float], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:hello, obj_.value.to_f] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        @config.delete_type(:hello_numbers)
        assert_equal([[:world, ::Float]], @config.all_patterns)
        assert_equal([:world_numbers], @config.all_types)
        assert_nil(@config.type_for_pattern([:hello, ::Integer]))
        assert_equal([], @config.patterns_for_type(:hello_numbers))
      end


      def test_cannot_add_to_locked_config
        @config.lock
        assert_raise(ConfigurationLockedError) do
          @config.add_pattern([:hello, ::Integer], :hello_numbers,
            ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
            ::Proc.new{ |obj_| [:hello, obj_.value] })
        end
      end


      def test_clear
        @config.add_pattern([:hello, ::Integer], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1]) },
          ::Proc.new{ |obj_| [:hello, obj_.value] })
        @config.add_pattern([:hello, ::Float], :hello_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:hello, obj_.value.to_f] })
        @config.add_pattern([:world, ::Float], :world_numbers,
          ::Proc.new{ |tuple_| Class1.new(tuple_[1].to_i) },
          ::Proc.new{ |obj_| [:world, obj_.value.to_f] })
        @config.clear
        assert_equal([], @config.all_patterns)
        assert_equal([], @config.all_types)
        assert_equal([], @config.all_categories)
        assert_equal(false, @config.has_pattern?([]))
        assert_equal(false, @config.has_type?(:type))
        assert_equal(false, @config.has_category?(:cat))
      end


    end

  end
end
