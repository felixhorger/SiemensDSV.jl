module SiemensDSV

	export dsvread

	using StringEncodings

	# TODO: use julia's load framework

	function parse_section(str::AbstractString)
		return Dict{String, String}(map(
			p -> Pair(p...),
			filter(
				v -> length(v) == 2,
				split.(split(str, "\r\n"), '=')
			)
		))
	end

	function dsvread(filename; max_time::Real=Inf)
		data = read(filename, String, Encoding("Latin1"))

		# This procedure could go into separate function, same for "frame"
		defs_start = findfirst("[DEFINITIONS]", data).stop + 3 # +3 for CR+LF+1
		defs_end = findnext("\r\n\r\n", data, defs_start).start - 2
		defs = parse_section(data[defs_start:defs_end])
		num_samples = parse(Int, defs["SAMPLES"])
		δt = parse(Float64, defs["HORIDELTA"])
		vertfactor = parse(Float64, defs["VERTFACTOR"])
		minlimit = parse(Float64, defs["MINLIMIT"])
		maxlimit = parse(Float64, defs["MAXLIMIT"])
		timeunit = defs["HORIUNITNAME"]
		# Why this test?
		#@assert timeunit == "µs" "Wrong time unit $(timeunit) != μs"

		frame_start = findfirst("[FRAME]", data).stop + 3 # Is the order of entries the same every time?
		frame_end = findnext("\r\n\r\n", data, frame_start).start - 2
		if frame_end > frame_start
			frame = parse_section(data[frame_start:frame_end])
		else
			frame = Dict{String, Any}()
		end
		# TODO: is the time axis needed, user can construct on their own?
		#if length(frame) != 0
		#	@warn "untested FRAME in DSV"
		#	time_start = frame["STARTTIME"] * 1e3  # STARTTIME is in ms -> μs
		#	time_end = frame["ENDTIME"] * 1e3
		#else
		#	time_start = 0
		#	time_end = time_start + (defs["SAMPLES"] - 1) * defs["HORIDELTA"]
		#end
		#time = time_start:defs["HORIDELTA"]:time_end
		#assert(numel(time)==samples,'Time vector length does not match number of samples.');

		vals_start = findfirst("[VALUES]", data).stop + 3
		vals_end = findlast("\r\n\r\n", data).start
		compressed = parse.(Int, split(data[vals_start:vals_end], "\r\n"))
		compression_ratio = length(compressed) / num_samples

		if !isinf(max_time)
			num_samples = floor(Int, max_time / δt) + 1
		end
		values = Vector{Float64}(undef, num_samples)
		prev_val = Float64(compressed[1])
		idx_compressed = 1
		idx = 1
		while idx_compressed <= length(compressed) && idx <= num_samples
			if idx_compressed + 2 <= length(compressed) && compressed[idx_compressed+1] == compressed[idx_compressed]
				# +2 accounts for idx_compressed and idx_compressed+1,
				# in addition to the number of further repetitions stored in idx_compressed+2
				num_repeat = compressed[idx_compressed+2] + 2
				val = compressed[idx_compressed]
				values[idx] = prev_val + val
				imax = min(idx+num_repeat-1, num_samples)
				for i = (idx+1):imax
					values[i] = values[i-1] + val
				end
				prev_val = values[imax]
				idx += num_repeat
				idx_compressed += 3
			else
				values[idx] = prev_val + compressed[idx_compressed]
				prev_val = values[idx]
				idx += 1
				idx_compressed += 1
			end
		end

		@. values = values / vertfactor

		# TODO: is this necessary? @assert all(v -> minlimit <= v <= maxlimit, values) "Values vector not in min-max range"
		return (; values, δt, timeunit, minlimit, maxlimit, compression_ratio, frame)
	end
end

