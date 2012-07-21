# -----------------------------------------------------------------------------
#
# ObjectRegistry railtie
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


require 'objectregistry'
require 'rails/railtie'


module ObjectRegistry


  # This railtie installs a middleware that clears out registries on
  # each request. Use the configuration to specify which registries.
  #
  # To install into a Rails app, include this line in your
  # config/application.rb:
  #   require 'objectregistry/railtie'
  # It should appear before your application configuration.
  #
  # You can then configure it using the standard rails configuration
  # mechanism. The configuration lives in the config.objectregistry
  # configuration namespace. See ObjectRegistry::Railtie::Configuration for
  # the configuration options.

  class Railtie < ::Rails::Railtie


    # Configuration options. These are attributes of config.objectregistry.

    class Configuration

      def initialize  # :nodoc:
        @repos = []
      end

      def add_repository(*repos_, &block_)
        repos_.flatten!
        opts_ = repos_.last.is_a?(::Hash) ? repos_.pop.dup : {}
        opts_[:repos] = repos_
        opts_[:block] = block_
        @repos << opts_
      end

    end


    config.objectregistry = Configuration.new


    initializer :initialize_objectregistry do |app_|
      repos_ = app_.config.objectregistry.instance_variable_get(:@repos)
      app_.config.middleware.use(RegistryCleanerMiddleware, repos_)
    end


  end


end
