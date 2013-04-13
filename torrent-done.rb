#!/usr/bin/env ruby

require "resque"
require "open4"
require "yaml"
require "active_support/inflector"
require "srt"
require "charlock_holmes"

require_relative "./jobs/base_job"
require_relative "./jobs/torrent_done"
require_relative "./jobs/download_subtitles"
require_relative "./jobs/convert_subtitles"
require_relative "./jobs/convert_and_rename"

if $PROGRAM_NAME == __FILE__
    directory = ARGV.first || [
        ENV["TR_TORRENT_DIR"],
        ENV["TR_TORRENT_NAME"]
    ].join("/")

    Resque.enqueue(TorrentDone, [], directory)
end
