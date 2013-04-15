class ConvertSubtitles < BaseJob
    @config = get_job_config() 
    @queue = @config["queue"]
    DIALOGUE = "Dialogue: Marked=0,%s,%s,Default,,0000,0000,0000,,%s"

    def self.execute(filename, subtitle_format)
        style = @config["style"] 
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        srt = SRT::File.parse(File.new("#{filename}.#{subtitle_format}", "r"))
        ssa = []

        srt.lines.each do |line|
            line = format_time(line.start_time), format_time(line.end_time), line.text.join("\\N")
            ssa << DIALOGUE % line
        end

        ssa = ssa.join("\n")

        File.open("#{filename}.ssa", "w") { |io| io.write("#{style}#{ssa}") }
        
        "ssa"
    end

    def self.format_time(t)
        t = t.round(2)
        time = t / 3600, (t % 3600) / 60, t % 60, (t.abs.modulo(1) * 100).to_i
        sprintf("%01d:%02d:%02d.%02d", *time)
    end
end
