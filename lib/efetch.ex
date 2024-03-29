

defmodule Efetch.Fetch do
  @moduledoc """
  Main module of Efetch
  Retreives system info
  Everything does exactly what you think they do
  """

  def grabos() do 
    case File.read("/etc/os-release") do 
      {:ok, contents} -> 
        case Regex.run(~r/PRETTY_NAME="([^"]+)"/, contents) do
          [_, pretty_name] -> {:ok, pretty_name}
          _ -> "Pretty name not found"
        end
      {:error, _} ->
        getos()
    end
  end

  @spec getos() :: {:ok, binary()} 
  def getos() do 
     raw = List.to_string :os.cmd('lsb_release -sd')
     os = String.replace(raw, "\"", "")
     out = String.replace(os, "\n", "")
     {:ok, out}
  end

  @spec gethost() :: {:error, binary()} | {:ok, binary()} 
  def gethost() do 
    case File.read("/sys/devices/virtual/dmi/id/product_name") do
      {:ok, file_contents} ->
        {:ok, String.replace(file_contents, "\n", "")}

      {:error, _} ->
        {:error, "product_name file not found"}
    end
  end

  @spec getkernel() :: {:ok, binary()} 
  def getkernel() do 
    out = :os.cmd('uname -r')
          |> List.to_string()
    {:ok, String.replace(out, "\n", "")}

  end

  @spec getuptime() :: {:ok, binary()}
  def getuptime() do 
    out = List.to_string :os.cmd('uptime')
    # regex = ~r/up\s+(\d+:\d+)/
    regex = ~r/up\s+(.*),\s+\d+\s+user/
    uptime = case Regex.run(regex, out) do
      [_, uptime] -> uptime
      nil -> "not found"
    end
    {:ok, uptime}
  end

  @spec formatuptime() :: {:ok, binary()}
  def formatuptime() do
    {:ok, time_str} = getuptime()
    [hours_str, minutes_str] = String.split(time_str, ":")
    hours = String.to_integer(hours_str)
    minutes = String.to_integer(minutes_str)

    hour_str = if hours == 1, do: "hour", else: "hours"
    min = if minutes == 1, do: "minute", else: "minutes"
    {:ok, "#{hours} #{hour_str} #{minutes} #{min}"}
  end

  def wrapuptime() do 
    try do 
      formatuptime()
    rescue
      _ -> getuptime()
    end
  end

  @spec getmemory() :: {:ok, %{total_mem: integer(), used_mem: integer()}} | {:error, binary()}
  defp getmemory() do 
    :application.start(:memsup)
    list = :memsup.get_system_memory_data()
    cond do
      is_integer(Keyword.get(list, :total_memory)) -> 
        total_mem = Keyword.get(list, :total_memory) / 1048576
        remain_mem = Keyword.get(list, :available_memory) / 1048576
        {
          :ok,
          %{
            :total_mem => round(total_mem),
            :used_mem => round(total_mem - remain_mem)
          }
        }
      !is_integer(Keyword.get(list, :total_memory)) -> 
        {:error, "memory is not integer"}
        
    end
  end

  @spec formatmem() :: {:ok, binary()}
  def formatmem() do
    {:ok, input} = getmemory()
    out = "#{Map.get(input, :used_mem)}MiB / #{Map.get(input, :total_mem)}MiB"
    {:ok, out}
  end
 
  @spec getshell() :: {:ok, nil | binary()}
  def getshell() do
    out = System.get_env("SHELL")
    {:ok, out}
  end

  @spec getterm() :: {:ok, nil | binary()}
  def getterm() do 
    out = System.get_env("TERM")
    {:ok, out}
  end

  @spec getsysinfo() :: {:ok, charlist()}
  def getsysinfo do
    out = :erlang.system_info(:system_architecture)                   
    {:ok, out}
  end 

  @spec getcpubrand() :: {:ok, binary()} | {:error, binary()}
  def getcpubrand() do
    case File.read("/proc/cpuinfo") do
      {:ok, contents} ->
      out = contents
          |> String.split("\n")
          |> Enum.find(fn line -> String.starts_with?(line, "model name") end)
          |> String.split(":")
          |> List.last()
          |> String.trim()
        {:ok, out}
      {:error, _} ->
        {:error, "unable to read /proc/cpuinfo"}
    end
  end
  
  @spec wrapcpubrand()  :: {:ok, binary()} | {:error, binary()}
  def wrapcpubrand() do
    try do
      getcpubrand() 
    rescue 
      _ -> 
        {:error, "unable to read /proc/cpuinfo"}
    end
  end

  @spec getuser() :: {:ok, binary()}
  def getuser() do
    out = :os.cmd('id -un')
          |> List.to_string()
          |> String.trim()
    {:ok, out}
  end

  @spec gethostname() :: {:ok, binary()}
  def gethostname() do
    case File.read("/proc/sys/kernel/hostname") do
      {:ok, file_contents} ->
        out = file_contents |> String.trim()
        {:ok, out}
      {:error, _} ->
        out = :os.cmd('hostname')
        |> List.to_string()
        {:ok, out}
    end
  end

  @spec formathostuser() :: {:ok, binary()}
  def formathostuser() do
    {_, user} = getuser()
    {_, host} = gethostname()
    out = "#{user}" <> "@" <> "#{host}"
    {:ok, out}
  end

  @spec lenline(binary() | nil) :: integer()
  def lenline(nil), do: 0
  def lenline( target ) do
    String.length(target)
  end

  @spec trylenline() :: integer()
  def trylenline() do
    {_, user} = getuser()
    {_, hostname} = gethostname()
    target = "#{user}@#{hostname}"
    try do
      lenline(target)
    rescue
      _ -> 0
    end
  end

  @spec printline(integer(), binary()) :: {:ok, binary()}
  def printline(target, acc \\ "")
  def printline(0, acc), do: {:ok, acc}
  def printline(target, acc) do
    printline(target - 1, acc <> "-")
  end

  def wrapprintline() do
    printline(trylenline())
  end

end

defmodule Efetch.Main do
  @moduledoc """
  Entry point.
  """
  alias Efetch.Fetch


  
  def queue() do
    # gosh this is ugly
    userbar = Task.async(Fetch, :formathostuser, [])
    line = Task.async(Fetch, :wrapprintline, [])
    os = Task.async(Fetch, :grabos, [])
    sysinfo = Task.async(Fetch, :getsysinfo, [])
    host = Task.async(Fetch, :gethost, [])
    kernel = Task.async(Fetch, :getkernel, [])
    uptime = Task.async(Fetch, :wrapuptime, [])
    term = Task.async(Fetch, :getterm, [])
    shell = Task.async(Fetch, :getshell, [])
    cpu = Task.async(Fetch, :wrapcpubrand, [])
    memory = Task.async(Fetch, :formatmem, [])

    {_, userbar} = Task.await(userbar)
    {_, line} = Task.await(line)
    {_, os} = Task.await(os)
    {_, sysinfo} = Task.await(sysinfo)
    {_, host} = Task.await(host)
    {_, kernel} = Task.await(kernel)
    {_, uptime} = Task.await(uptime)
    {_, term} = Task.await(term)
    {_, shell} = Task.await(shell)
    {_, cpu} = Task.await(cpu)
    {_, memory} = Task.await(memory)

    IO.puts(userbar)
    IO.puts(line)
    IO.puts("operating system: #{os}")
    IO.puts("os info: #{sysinfo}")
    IO.puts("host: #{host}")
    IO.puts("kernel: #{kernel}")
    IO.puts("uptime: #{uptime}")
    IO.puts("terminal: #{term}")
    IO.puts("shell: #{shell}")
    IO.puts("cpu: #{cpu}")
    IO.puts("memory: #{memory}")

    {:ok, "success"}
  end

  def start(_types, _args) do
    queue()
    System.halt(0)
    {:ok, self()}
  end

end 


