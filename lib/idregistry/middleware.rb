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


  # A Rack middleware that manages registries around a request.
  #
  # Configure this middleware with a set of registry-related tasks,
  # such as creating temporary registries scoped to the request, or
  # clearing registries at the end of the request.
  #
  # A task object must include two methods: pre and post.
  # These methods are called before and after the request, and are
  # passed the Rack environment hash.

  class RegistryMiddleware


    # A registry task that clears a registry at the end of a request.
    #
    # You may also provide an optional condition block, which is called
    # and passed the Rack env to determine whether the registry should
    # be cleared. If no condition block is provided, the registry is
    # always cleared.

    class ClearRegistry

      # Create a new ClearRegistry task. You must provide the registry
      # and an optional condition block.
      def initialize(registry_, &condition_)
        @condition = condition_
        @registry = registry_
      end

      # The pre method for this task does nothing.
      def pre(env_)
      end

      # The post method for this task clears the registry if the
      # condition block passes
      def post(env_)
        if !@condition || @condition.call(env_)
          @registry.clear
        end
      end

    end


    # A registry task that spawns a registry scoped to this request.
    #
    # You must provide a locked registry configuration to use as a
    # template. The spawned registry will use the given configuration.
    # You must also provide a key, which will be used to store the
    # spawned registry in the Rack environment so that your application
    # can access it.

    class SpawnRegistry

      # Create a new ClearRegistry task. You must provide a locked
      # template configuration and a key into the Rack environment.
      def initialize(template_, envkey_)
        @template = template_
        @envkey = envkey_
        @registry = nil
      end

      # The pre method for this task creates a new registry.
      def pre(env_)
        @registry = env_[@envkey] = @template.spawn_registry
      end

      # The post method for this task clears the spawned registry.
      def post(env_)
        if @registry
          @registry.clear
          @registry = nil
          env_.delete(@envkey)
        end
      end

    end


    # Create a middleware.
    #
    # After the required Rack app argument, provide an array of tasks.

    def initialize(app_, tasks_=[], opts_={})
      @app = app_
      @tasks = tasks_
    end


    # Wrap the Rack app with registry tasks.

    def call(env_)
      begin
        @tasks.each{ |task_| task_.pre(env_) }
        return @app.call(env_)
      ensure
        @tasks.each{ |task_| task_.post(env_) }
      end
    end


  end


end
