# -----------------------------------------------------------------------------
#
# IDRegistry railtie
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


require 'idregistry'
require 'rails/railtie'


module IDRegistry


  # This railtie installs and configures a middleware that helps you
  # manage registries around Rails requests. See RegistryMiddleware for
  # details.
  #
  # To install into a Rails app, include this line in your
  # config/application.rb:
  #   require 'idregistry/railtie'
  # It should appear before your application configuration.
  #
  # You can then configure it using the standard rails configuration
  # mechanism. The configuration lives in the config.idregistry
  # configuration namespace. See IDRegistry::Railtie::Configuration for
  # the configuration options.

  class Railtie < ::Rails::Railtie


    # Configuration options. These are methods on config.idregistry.

    class Configuration

      def initialize  # :nodoc:
        @tasks = []
        @before_middleware = nil
      end


      # Array of registry tasks
      attr_accessor :tasks

      # Middleware to run before, or nil to run the middleware toward the end
      attr_accessor :before_middleware


      # Set up the middleware to clear the given registry after each
      # request.
      #
      # If you provide the optional block, it is called and passed the
      # Rack environment. The registry is cleared only if the block
      # returns a true value. If no block is provided, the registry is
      # always cleared at the end of a request.
      #
      # If you set the <tt>:before_request</tt> option to true, the
      # registry clearing will take place at the beginning of the request
      # rather than the end.

      def clear_registry(reg_, opts_={}, &condition_)
        @tasks << RegistryMiddleware::ClearRegistry.new(reg_, opts_, &condition_)
        self
      end


      # Set up the middleware to spawn a new registry on each request,
      # using the given locked configuration as a template. The new
      # registry is stored in the Rack environment with the given key.
      # It is cleaned and disposed at the end of the request.

      def spawn_registry(template_, envkey_)
        @tasks << RegistryMiddleware::SpawnRegistry.new(template_, envkey_)
        self
      end


    end


    config.idregistry = Configuration.new


    initializer :initialize_idregistry do |app_|
      config_ = app_.config.idregistry
      stack_ = app_.config.middleware
      if (before_ = config_.before_middleware)
        stack_.insert_before(before_, RegistryMiddleware, config_.tasks)
      else
        stack_.use(RegistryMiddleware, config_.tasks)
      end
    end


  end


end
