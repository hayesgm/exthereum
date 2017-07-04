defmodule HexPrefix do
	@moduledoc """
	A simple module for hex-profix encoding, as depicted
	in Appendix C of https://ethereum.github.io/yellowpaper/paper.pdf
	"""

	@type t :: {[0x0..0xf], boolean()}

  @doc """
  Encodes a list of nibbles using hex-prefix notation.

  ## Examples

    iex> HexPrefix.encode({[0xa, 0xb, 0xc, 0xd], false})
    <<0, 171, 205>>

    iex> HexPrefix.encode({[0xa, 0xb, 0xc, 0xd], true})
    <<32, 171, 205>>

    iex> HexPrefix.encode({[0x09, 0xa, 0xb, 0xc, 0xd], false})
    <<25, 171, 205>>

    iex> HexPrefix.encode({[0x09, 0xa, 0xb, 0xc, 0xd], true})
    <<57, 171, 205>>

    iex> HexPrefix.encode({[ 1, 2, 3, 4, 5 ], false})
    <<0x11, 0x23, 0x45>>

    iex> HexPrefix.encode({[ 0, 1, 2, 3, 4, 5 ], false})
    <<0x00, 0x01, 0x23, 0x45>>

    iex> HexPrefix.encode({[ 0, 15, 1, 12, 11, 8 ], true})
    <<0x20, 0x0f, 0x1c, 0xb8>>

    iex> HexPrefix.encode({[ 15, 1, 12, 11, 8 ], true})
    <<0x3f, 0x1c, 0xb8>>
  """
	@spec encode(__MODULE__.t) :: binary()
	def encode({nibbles, terminator}) do
		{base, nibbles} = if rem(length(nibbles), 2) == 0 do # even
      {<<16*f(terminator)>>, nibbles}
    else
      {<<16*(f(terminator)+1)+hd(nibbles)>>, tl(nibbles)}
    end

    # Group in pairs, we know it's even
    Enum.reduce(nibbles |> Enum.chunk(2), base, fn([n1, n2], acc) ->
      acc <> <<16*n1+n2::8>>
    end)
	end

  defp f(false), do: 0
  defp f(true), do: 2

  @doc """
  Decodes a binary encoded via hex-prefix notation.

  ## Examples

    iex> HexPrefix.decode(<<0, 171, 205>>)
    {[0xa, 0xb, 0xc, 0xd], false}

    iex> HexPrefix.decode(<<32, 171, 205>>)
    {[0xa, 0xb, 0xc, 0xd], true}

    iex> HexPrefix.decode(<<25, 171, 205>>)
    {[0x09, 0xa, 0xb, 0xc, 0xd], false}

    iex> HexPrefix.decode(<<57, 171, 205>>)
    {[0x09, 0xa, 0xb, 0xc, 0xd], true}

    iex> HexPrefix.decode(<<0x11, 0x23, 0x45>>)
    {[ 1, 2, 3, 4, 5 ], false}

    iex> HexPrefix.decode(<<0x00, 0x01, 0x23, 0x45>>)
    {[ 0, 1, 2, 3, 4, 5 ], false}

    iex> HexPrefix.decode(<<0x20, 0x0f, 0x1c, 0xb8>>)
    {[ 0, 15, 1, 12, 11, 8 ], true}

    iex> HexPrefix.decode(<<0x3f, 0x1c, 0xb8>>)
    {[ 15, 1, 12, 11, 8 ], true}
  """
  @spec decode(binary()) :: {:ok, __MODULE__.t} | :error
  def decode(hp) do
    # First two bits are unused, then encode terminator, then parity, then maybe first nibble, then rest
    # We just pattern match for each
    <<_::size(2), terminator::size(1), parity::size(1), hd::bitstring - size(4), rest::binary>> = hp

    # Ignore first nibble unless parity flag is set
    base = if parity == 1, do: [:binary.decode_unsigned(<<0::4, hd::bits>>, :big)], else: []

    nibbles = base ++ for <<nibble::4 <- rest>>, do: nibble

    {nibbles, terminator == 1}
  end
end