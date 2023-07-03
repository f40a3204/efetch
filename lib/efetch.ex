

defmodule Efetch.Fetch do
  @moduledoc """
  Main module of Efetch
  Retreives system info
  Everything does exactly what you think they do
  """

  @spec getos() :: binary() 
  def getos do 
     raw = List.to_string :os.cmd('lsb_release -sd')
     os = String.replace(raw, "\"", "")
     String.replace(os, "\n", "")
  end

  @spec gethost() :: binary() 
  def gethost do 
    case File.read("/sys/devices/virtual/dmi/id/product_name") do
      {:ok, file_contents} ->
        String.replace(file_contents, "\n", "")

      {:error, _} ->
        "not found"
    end
  end

  @spec getkernel() :: binary() 
  def getkernel do 
    out = :os.cmd('uname -r')
          |> List.to_string()
    String.replace(out, "\n", "")
  end

  @spec getuptime() :: binary()
  defp getuptime do 
    out = List.to_string :os.cmd('uptime')
    # regex = ~r/up\s+(\d+:\d+)/
    regex = ~r/up\s+(.*),\s+\d+\s+user/
    uptime = case Regex.run(regex, out) do
      [_, uptime] -> uptime
      nil -> "not found"
    end
    uptime
  end

  @spec formatuptime() :: binary()
  def formatuptime do
    time_str = getuptime()
    [hours_str, minutes_str] = String.split(time_str, ":")
    hours = String.to_integer(hours_str)
    minutes = String.to_integer(minutes_str)

    hour_str = if hours == 1, do: "hour", else: "hours"
    min = if minutes == 1, do: "minute", else: "minutes"
    "#{hours} #{hour_str} #{minutes} #{min}"
  end

  @spec getmemory() :: %{total_mem: integer, used_mem: integer} | :error
  defp getmemory do 
    :application.start(:memsup)
    list = :memsup.get_system_memory_data()
    cond do
      is_integer(Keyword.get(list, :total_memory)) -> 
        total_mem = Keyword.get(list, :total_memory) / 1048576
        remain_mem = Keyword.get(list, :available_memory) / 1048576
        %{
          :total_mem => round(total_mem),
          :used_mem => round(total_mem - remain_mem)
        }
      !is_integer(Keyword.get(list, :total_memory)) -> 
        :error
        
    end
  end

  @spec formatmem() :: binary()
  def formatmem() do
    input = getmemory()
    case input do
      :error -> "error"
      _ -> "#{Map.get(input, :used_mem)}MiB / #{Map.get(input, :total_mem)}MiB"
    end
  end
 
  @spec getshell() :: binary()
  def getshell() do
    System.get_env("SHELL")
  end

  @spec getterm() :: binary()
  def getterm() do 
    System.get_env("TERM")
  end

  @spec getsysinfo() :: charlist()
  def getsysinfo do
    :erlang.system_info(:system_architecture)                   
  end 

  @spec getcpubrand() :: binary()
  def getcpubrand() do
    {:ok, contents} = File.read("/proc/cpuinfo")
    brand = contents
            |> String.split("\n")
            |> Enum.find(fn line -> String.starts_with?(line, "model name") end)
            |> String.split(":")
            |> List.last()
            |> String.trim()
    brand
  end

  @spec getuser() :: binary()
  def getuser() do
    System.get_env("USER")
  end

  @spec gethostname() :: binary()
  def gethostname() do
    case File.read("/proc/sys/kernel/hostname") do
      {:ok, file_contents} ->
        file_contents |> String.trim()
      {:error, _} ->
        :os.cmd('hostname')
        |> List.to_string()
    end
  end

  @spec lenline(binary() | nil) :: integer()
  def lenline( target \\ getuser()<>"@"<>gethostname() ) 
  def lenline(nil), do: 0
  def lenline( target ) do
    String.length(target)
  end

  def trylenline() do
    try do
      lenline()
    rescue
      _ -> 0
    end
  end

  @spec printline(integer(), binary()) :: binary()
  def printline(target, acc \\ "")
  def printline(0, acc), do: acc
  def printline(target, acc) do
    printline(target - 1, acc <> "-")
  end

  @spec start() :: :ok
  def start do
    IO.puts "#{IO.ANSI.green}#{getuser()}#{IO.ANSI.reset}@#{IO.ANSI.green}#{gethostname()}#{IO.ANSI.reset}"
    IO.puts "#{printline(trylenline())}"
    IO.puts "#{IO.ANSI.green}operating system:#{IO.ANSI.reset} #{getos()}"
    IO.puts "#{IO.ANSI.green}host:#{IO.ANSI.reset} #{gethost()}"
    IO.puts "#{IO.ANSI.green}kernel:#{IO.ANSI.reset} #{getkernel()}"
    IO.puts "#{IO.ANSI.green}uptime:#{IO.ANSI.reset} #{getuptime()}"
    IO.puts "#{IO.ANSI.green}memory:#{IO.ANSI.reset} #{formatmem()}"
    IO.puts "#{IO.ANSI.green}shell:#{IO.ANSI.reset} #{getshell()}"
    IO.puts "#{IO.ANSI.green}terminal:#{IO.ANSI.reset} #{getterm()}"
    IO.puts "#{IO.ANSI.green}cpu:#{IO.ANSI.reset} #{getcpubrand()}"
  end

end

defmodule Efetch.Main do
  @moduledoc """
  Entry point.
  """
  def start(_types, _args) do
    Efetch.Fetch.start()
    System.halt(0)
    {:ok, self()}
  end

end 


