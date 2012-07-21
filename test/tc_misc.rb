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


module IDRegistry
  module Tests  # :nodoc:

    class TestMisc < ::Test::Unit::TestCase  # :nodoc:


      def test_match_basic
        assert_equal(true, Utils.matches?([:foo, ::Integer], [:foo, 1]))
      end


      def test_match_wrong_class
        assert_equal(false, Utils.matches?([:foo, ::Integer], [:foo, 'bar']))
      end


      def test_match_extra_items
        assert_equal(false, Utils.matches?([:foo, ::Integer], [:foo, 1, 2]))
      end


      def test_match_missing_items
        assert_equal(false, Utils.matches?([:foo, ::Integer], [:foo]))
      end


      def test_match_multiple_classes
        assert_equal(true, Utils.matches?([:foo, ::Integer, ::Integer], [:foo, 3, 4]))
      end


      def test_match_multiple_classes_missing_items
        assert_equal(false, Utils.matches?([:foo, ::Integer, ::Integer], [:foo, 1]))
      end


      def test_match_multiple_classes_extra_items
        assert_equal(false, Utils.matches?([:foo, ::Integer, ::Integer], [:foo, 1, 2, 3]))
      end


      def test_match_wrong_constant
        assert_equal(false, Utils.matches?([:foo, ::Integer, ::Integer], [:bar, 2, 3]))
      end


      def test_match_multiple_different_classes
        assert_equal(true, Utils.matches?([:foo, ::Integer, ::String], [:foo, 2, 'bar']))
      end


      def test_match_multiple_constants
        assert_equal(true, Utils.matches?([:foo, :bar, ::String], [:foo, :bar, 'bar']))
      end


      def test_match_multiple_constants_wrong_constant
        assert_equal(false, Utils.matches?([:foo, :bar, ::String], [:foo, :baz, 'bar']))
      end


      def test_match_symbols_and_strings
        assert_equal(true, Utils.matches?([::Symbol, 1, 3, ::String], [:foo, 1, 3, 'bar']))
        assert_equal(false, Utils.matches?([::Symbol, 1, 3, ::String], ['foo', 1, 3, 'bar']))
      end


    end

  end
end
