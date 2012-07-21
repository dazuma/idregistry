# -----------------------------------------------------------------------------
#
# IDRegistry middleware
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


  # A Rack middleware that cleans up a registry after a request
  # has completed.

  class RegistryCleanerMiddleware


    # Create a middleware object for Rack.

    def initialize(app_, repos_=[], opts_={})
      @app = app_
      @repos = repos_
    end


    def call(env_)
      begin
        @repos.each do |repo_data_|
          if repo_data_[:before_request]
            block_ = repo_data_[:block]
            if !block_ || block_.call(env_)
              repo_data_[:repos].each{ |repo_| repo_.clear }
            end
          end
        end
        return @app.call(env_)
      ensure
        @repos.each do |repo_data_|
          unless repo_data_[:before_request]
            block_ = repo_data_[:block]
            if !block_ || block_.call(env_)
              repo_data_[:repos].each{ |repo_| repo_.clear }
            end
          end
        end
      end
    end


  end


end
