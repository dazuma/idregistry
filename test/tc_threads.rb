# -----------------------------------------------------------------------------
#
# Thread safety tests
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

    class TestThreads < ::Test::Unit::TestCase  # :nodoc:


      Class1 = ::Struct.new(:value)


      def test_simultaneous_lookup
        counter_ = 0
        objects_ = []
        registry_ = IDRegistry.create do
          add_pattern([:hello, ::Integer]) do |tuple_|
            sleep(0.1)
            counter_ += 1
            Class1.new(tuple_[1])
          end
        end
        ::Array.new(2) do |i_|
          ::Thread.new do
            objects_ << registry_.lookup(:hello, 1)
          end
        end.each do |t_|
          t_.join
        end
        assert_equal(2, counter_)
        assert_equal(2, objects_.size)
        assert_equal(1, registry_.size)
        assert_equal(objects_[0].object_id, objects_[1].object_id)
      end


    end

  end
end
