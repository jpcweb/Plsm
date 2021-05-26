defmodule PlsmTest do
  use ExUnit.Case

  @schema_dir "lib/test_temp/schemas/"

  describe "plsm task using postgres" do
    setup do
      Application.put_env(:plsm, :server, "127.0.0.1")
      Application.put_env(:plsm, :port, "5433")
      Application.put_env(:plsm, :database_name, "plsm_test")
      Application.put_env(:plsm, :username, "postgres")
      Application.put_env(:plsm, :password, "password")
      Application.put_env(:plsm, :type, :postgres)
      Application.put_env(:plsm, :module_name, "PlsmTest")
      Application.put_env(:plsm, :destination, @schema_dir)

      File.ls!("#{@schema_dir}")
      |> Enum.filter(fn file -> !String.starts_with?(file, ".") end)
      |> Enum.each(fn file -> File.rm!(file) end)

      :ok
    end

    test "schema files are generated and can compile" do
      Mix.Tasks.Plsm.run([])

      assert :ok == IEx.Helpers.recompile()
    end
  end
end
