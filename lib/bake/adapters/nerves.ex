defmodule Bake.Adapters.Nerves do
  @behaviour Bake.Adapter

  @nerves_home System.get_env("NERVES_HOME") || "~/.nerves"

  require Logger

  def systems_path, do: "#{@nerves_home}/systems/" |> Path.expand
  def toolchains_path, do: "#{@nerves_home}/toolchains/" |> Path.expand

  def firmware(config, target, otp_name) do
    Bake.Shell.info "=> Building firmware for target #{target}"
    target_atom =
    cond do
      is_atom(target) -> target
      true -> String.to_atom(target)
    end

    target_config = config
    |> Keyword.get(:target)
    |> Keyword.get(target_atom)
    recipe = target_config[:recipe]
    # TODO: Need to get locked version from the bakefile.lock

    # Check to ensure that the system is available in NERVES_HOME
    system_path = "#{systems_path}/#{recipe}"
    #Logger.debug "Path: #{inspect system_path}"
    if File.dir?(system_path) do
      #Logger.debug "System #{recipe} Found"
    else
      raise "System #{inspect recipe} not downloaded"
    end
    # Read the recipe config from the system
    {:ok, system_config} = "#{system_path}/config.exs"
    |> Bake.Config.Recipe.read!

    rel2fw = "#{system_path}/scripts/rel2fw.sh"

    #Logger.debug "System Config: #{inspect system_config}"
    # Toolchain
    {username, toolchain_tuple, _toolchain_version} = system_config[:toolchain]
    host_platform = BakeUtils.host_platform
    host_arch = BakeUtils.host_arch
    toolchain_name = "#{username}-#{toolchain_tuple}-#{host_platform}-#{host_arch}"

    toolchains = File.ls!(toolchains_path)
    toolchain_name = Enum.find(toolchains, &(String.starts_with?(&1, toolchain_name)))
    toolchain_path = "#{toolchains_path}/#{toolchain_name}"
    if File.dir?(toolchain_path) do
      #Logger.debug "Toolchain #{toolchain_tuple} Found"
    else
      raise "Toolchain #{username}-#{toolchain_tuple}-#{host_platform}-#{host_arch} not downloaded"
    end

    stream = IO.binstream(:standard_io, :line)
    env = [
      {"NERVES_APP", File.cwd!},
      {"NERVES_TOOLCHAIN", toolchain_path},
      {"NERVES_SYSTEM", system_path},
      {"MIX_ENV", System.get_env("MIX_ENV") || "dev"}
    ]
    cmd = """
    source nerves-env.sh &&
    cd #{File.cwd!} &&
    mix release &&
    sh #{rel2fw} rel/#{otp_name} _images/#{otp_name}-#{target}.fw
    """ |> remove_newlines
    Porcelain.shell(cmd, dir: system_path, env: env, out: stream)
  end

  def burn(config, target, otp_name) do

  end

  defp remove_newlines(string) do
    string |> String.strip |> String.replace("\n", " ")
  end
end
