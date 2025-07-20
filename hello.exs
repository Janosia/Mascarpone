defmodule Hello do
  def world(name) do
    IO.puts("Hello World from #{name}!")
  end
end

Hello.world("Janosia")
