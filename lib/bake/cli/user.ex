defmodule Bake.Cli.User do
  @menu "user"
  @switches [clean_pass: :boolean]

  use Bake.Cli.Menu
  alias Bake.Utils

  def menu do
    """
      register  - Register a new user
      whoami    - Display current authorized user
      test      - Check user authorization
      auth      - Authoriza as a user
      deauth    - Deauthorize the local user
    """
  end

  def main(args) do
    Bake.start
    {opts, cmd, _} = OptionParser.parse(args, switches: @switches)
    opts = Enum.into(opts, %{})
    case cmd do
      ["register"] -> register(opts)
      ["whoami"] -> whoami
      ["test"] -> test
      ["deauth"] -> deauth
      ["auth"] -> create_key(opts)
      _ -> invalid_cmd(cmd)
    end
  end

  defp register(opts) do
    clean? = Map.get(opts, :clean_pass, true)

    username = Bake.Shell.prompt("Username:")  |> String.strip
    email    = Bake.Shell.prompt("Email:")     |> String.strip
    password = Utils.password_get("Password:", clean?) |> String.strip
    unless is_nil(password) do
      confirm = Utils.password_get("Password (confirm):", clean?) |> String.strip
      if password != confirm do
        raise Bake.Error, message: "Entered passwords do not match"
      end
    end
    Bake.Shell.info("Registering...")
    create_user(username, email, password)
  end

  defp whoami do
    config = Bake.Config.Global.read
    username = Bake.Utils.local_user(config)
    Bake.Shell.info(username)
  end

  defp create_user(username, email, password) do
    user = %{username: username, email: email, password: password}
    case Bake.Api.User.create(user) do
      {:ok, %{status_code: status_code}} when status_code in 200..299 ->
        Utils.generate_key(username, password)
        Bake.Shell.info(
          "Account Created\n" <>
          "A confirmation email has been sent to #{email}"
        )
      {_, response} ->
        Bake.Shell.error("Registration failed")
        Bake.Utils.print_response_result(response)
    end
  end

  defp test do
    config = Bake.Config.Global.read
    username = Bake.Utils.local_user(config)
    auth = Bake.Utils.auth_info(config)

    case Bake.Api.User.get(username, auth) do
      {:ok, %{status_code: status_code}} when status_code in 200..299 ->
        Bake.Shell.info("Authorization Successful")
      {_, response} ->
        Bake.Shell.error("Failed to auth")
        Bake.Utils.print_response_result(response)
    end
  end

  defp create_key(opts) do
    clean? = Map.get(opts, :clean_pass, true)

    username = Bake.Shell.prompt("Username:")
      |> String.strip
    password = Utils.password_get("Password:", clean?)
      |> String.strip

    Utils.generate_key(username, password)
  end

  defp deauth() do
    config = Bake.Config.Global.read
    username = Bake.Utils.local_user(config)

    config
    |> Keyword.drop([:username, :key])
    |> Bake.Config.Global.write

    Bake.Shell.info "User `" <> username <> "` removed from the local machine. " <>
                   "To authenticate again, run `bake user auth` " <>
                   "or create a new user with `bake user register`"
  end
end
