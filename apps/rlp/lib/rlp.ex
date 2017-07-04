defmodule RLP do
	@moduledoc """
	RLP allows you to encode or decode RLP strings, acoording
	to the Yellow Paper spec: https://ethereum.github.io/yellowpaper/paper.pdf (Appendix B)
	"""

	use Bitwise

	@type t :: [t] | binary()

	@sentinel_single_byte 				0x80
	@sentinel_single_byte_str_start 	0xb7
	@sentinel_multi_byte_str_start 		0xc0
	@sentinel_single_byte_arr_start 	0xf7

	@max_single_byte_size 				55


	@doc """
	Given an RLP-encoded string, returns a
	decoded RPL structure (which is an array
	of RLP structures or binaries).

	## Examples

		iex> RLP.decode(<<0x83, ?d, ?o, ?g>>)
		"dog"

		iex> RLP.decode(<<184, 60, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65>>)
		Enum.join(for _ <- 1..60, do: "A")

		iex> RLP.decode(<<0xc8, 0x83, ?c, ?a, ?t, 0x83, ?d, ?o, ?g>>)
		["cat", "dog"]

    iex> RLP.decode(<<198, 51, 132, 99, 111, 111, 108>>)
    ["3", "cool"]

		iex> RLP.decode(<<0x80>>)
		""

		iex> RLP.decode(<<0xc0>>)
		[]

		iex> RLP.decode(<<0x0f>>)
		<<0x0f>>

		iex> RLP.decode(<<0x82, 0x04, 0x00>>)
		"\x04\x00"

		iex> RLP.decode(<<0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0>>)
		[[],[[]],[[],[[]]]]

		iex> RLP.decode(<<248, 60, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247, 247>>)
		for _ <- 1..60, do: []
	"""

	@spec decode(String.t) :: __MODULE__.t
	def decode(str) do
		{res, _} = do_decode(str)

		res
	end

	# Decodes string and returns item plus number of bytes consumed
	def do_decode(str) do
		case str do
			# Nothing
			"" -> nil
			# Single byte
			<<x,_::binary>> when x < @sentinel_single_byte -> {<<x>>, 1}
			# Single byte array
			<<x,rest::binary>> when x < @sentinel_single_byte_str_start ->
				str_len = x - @sentinel_single_byte

				<<str::binary - size(str_len), _::binary>> = rest

				{str, 1+str_len}
			# Multi-byte array ->
			<<x,rest::binary>> when x < @sentinel_multi_byte_str_start ->
				len = ( x - @sentinel_single_byte_str_start )
				bit_len = len * 8
				<<str_len::size(bit_len),rest_2::binary>> = rest
				<<str::binary - size(str_len)>> = rest_2

				{str, 1+len+str_len}
			# Single-byte list
			<<x,rest::binary>> when x < @sentinel_single_byte_arr_start ->
				arr_len = x - @sentinel_multi_byte_str_start

				items = take_items(<<rest::binary - size(arr_len)>>, arr_len)

				Enum.reduce(items, {[], 1}, fn ({item, size}, {items, total_size}) ->
					{items++[item], total_size + size}
				end)
			# Multi-byte list (TODO)
			<<x,rest::binary>> ->
				arr_len_len = x - @sentinel_single_byte_arr_start
				<<encoded_len::binary - size(arr_len_len),rest_2::binary>>=rest

				total_len = decode_variable_length(encoded_len)

				items = take_items(<<rest_2::binary - size(total_len)>>, total_len)

				Enum.reduce(items, {[], 1}, fn ({item, size}, {items, total_size}) ->
					{items++[item], total_size + size}
				end)

			_ -> nil
		end
	end

	defp take_items(_str, 0), do: []
	defp take_items(str, total_len) do
		# Grab first item

		{rlp, len} = do_decode(str)

		# if we're out of bytes, exit
		remaining_len = total_len - len

		if remaining_len == 0 do
			[{rlp, len}]
		else
			# recurse on rest of binary
			<<_::binary - size(len),rest::binary>> = str

			[{rlp, len}] ++ take_items(rest, remaining_len)
		end
	end

	@doc """
	Given an RLP structure, returns the encoding
	as a string.

	## Examples

		iex> RLP.encode("dog")
		<<0x83, ?d, ?o, ?g>>

		iex> RLP.encode(Enum.join(for _ <- 1..60, do: "A"))
		<<184, 60, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65>>

		iex> RLP.encode(["cat", "dog"])
		<<0xc8, 0x83, ?c, ?a, ?t, 0x83, ?d, ?o, ?g>>

		iex> RLP.encode("")
		<<0x80>>

		iex> RLP.encode([])
		<<0xc0>>

		iex> RLP.encode("\x0f")
		<<0x0f>>

		iex> RLP.encode("\x04\x00")
		<<0x82, 0x04, 0x00>>

		iex> RLP.encode([[],[[]],[[],[[]]]])
		<<0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0>>

		iex> RLP.encode(for _ <- 1..60, do: [])
		<<248, 60, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192>>
	"""

	@spec encode(__MODULE__.t) :: String.t
	def encode(rlp) do
		do_encode(rlp)
	end

	defp do_encode(rlp) do
		case rlp do
			<<i::size(8)>> when i < @sentinel_single_byte -> <<i>>
			str when is_binary(str) ->
				encode_variable_length_string(@sentinel_single_byte, @max_single_byte_size, @sentinel_single_byte_str_start, byte_size(str)) <> str

			lst when is_list(lst) ->
				parts = for part <- lst, do: do_encode(part)
				total_len = Enum.reduce(parts, 0, fn (p, acc) -> acc + byte_size(p) end)

				base = encode_variable_length_string(@sentinel_multi_byte_str_start, @max_single_byte_size, @sentinel_single_byte_arr_start, total_len)

				Enum.reduce(parts, base, fn (part, res) ->
					res <> part
				end)
		end
	end

	# Encodes a string either single-byte or multi-byte
	defp encode_variable_length_string(single_byte_start, single_byte_max, multibyte_start, str_len) do
		if str_len <= single_byte_max do
			<<single_byte_start+str_len>>
		else
      len_encoded = encode_variable_length(str_len)
			<<multibyte_start + byte_size(len_encoded)>> <> len_encoded
		end
	end

	defp encode_variable_length(l), do: :binary.encode_unsigned(l)
	def decode_variable_length(l), do: :binary.decode_unsigned(l)
end
