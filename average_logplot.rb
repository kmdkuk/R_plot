require 'fileutils'
require 'gnuplot'

def directory_conf(path)
  FileUtils.mkdir_p(path) unless FileTest.exist?(path)
end

def cat_all(percent, log_path)
  output_file = "./resources/#{log_path}/log-#{percent}-all.txt"
  FileUtils.rm(output_file) if File.exist?(output_file)

  command = "cat ./resources/#{log_path}/log-#{percent}-* > #{output_file}"
  puts "exec #{command}"
  `#{command}`
end

def create_hash(filename)
  hash = {}
  File.open('./resources/' + filename) do |file|
    puts 'start createhash'
    file.each_line do |l|
      ip = l.match(/(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/)
      next if ip.nil?

      time =  l.match(/([0-9]*).0ns/)[1]
      second = l.match(/([0-9]*).0ns\Z/)[1]

      hash[ip.to_s] = {} if hash[ip.to_s].nil?
      # puts 'time: ' + time
      # puts 'second: ' + second
      hash[ip.to_s][time.to_s] = second.to_s
    end
  end
  puts 'done'
  hash
  # 例外は小さい単位で捕捉する
rescue SystemCallError => e
  puts %(class=[#{e.class}] message=[#{e.message}])
rescue IOError => e
  puts %(class=[#{e.class}] message=[#{e.message}])
end

def search_range(hash)
  x_max = Float::MIN
  x_min = Float::MAX
  y_max = Float::MIN
  y_min = Float::MAX
  hash.each do |_ip, timeset|
    timeset.each do |time, second|
      x_max = time if x_max < time.to_f
      x_min = time if x_min > time.to_f
      y_max = second if y_max < second.to_f
      y_min = second if y_min > second.to_f
    end
  end

  x_max /= 1_000_000_000
  x_min /= 1_000_000_000
  y_max /= 1_000_000
  y_min /= 1_000_000
  { x_max: x_max, x_min: x_min, y_max: y_max, y_min: y_min }
end

def create_ip_summary(hash)
  # ここに来たらlogファイルがhashに格納されている
  # それを一回1ms感覚で集約したい
  # summary[ip][time] = second
  each_ip_summary = {} # 集約結果を入れる

  hash.each do |ip, timeset|
    # xをnsオーダーで切り捨てて
    time_summary = {} # time_summary[経過時間] = 遅延の集約結果を入れる
    time_sum = {} # time_sum[経過時間] = その間の間の遅延の合計
    time_count = {} # time_count[経過時間] = 経過時間の間の出現回数
    timeset.each do |time, second|
      var = time.to_f.floor(-9) # 0.1秒単位で均した経過秒数
      time_sum[var] = 0 if time_sum[var].nil?
      time_summary[var] = 0 if time_summary[var].nil?
      time_count[var] = 0 if time_count[var].nil?
      time_count[var] += 1
      time_sum[var] += second.to_f
      time_summary[var] = time_sum[var] / time_count[var]
    end
    each_ip_summary[ip] = time_summary
  end
  each_ip_summary
end

def create_summary(ip_summary)
  summary = {}

  ip_summary.each do |_ip, timeset|
    timeset.each do |time, latency|
      summary[time] = 0 if summary[time].nil?
      summary[time] += latency
    end
  end

  summary.each do |time, latency|
    summary[time] = latency / 5
  end
  summary
end

def data_create(timeset)
  x = []
  y = []
  timeset.each do |time, second|
    x.push time.to_f / 1_000_000_000
    y.push second.to_f / 1_000_000
  end
  [x, y]
end

def print_each_ip(ip_summary, path, range)
  ip_summary.each do |ip, timeset|
    Gnuplot.open do |gp|
      Gnuplot::Plot.new(gp) do |plot|
        puts "#{ip} のグラフ生成開始"
        plot.title 'サービスレスポンスタイムの推移'
        plot.xlabel '経過時間(s)'
        plot.xrange "[#{range[:x_min].to_i - 5}:#{range[:x_max].to_i + 5}]"
        plot.ylabel 'サービスレスポンスタイム(ms)'
        plot.yrange "[#{range[:y_min].to_i - 5}:#{range[:y_max].to_i + 5}]"
        plot.set 'size 1,1'
        plot.terminal "png enhanced font 'IPA P ゴシック' fontscale 1.2"
        plot.output "#{path}/#{ip}.png"
        # plot.set "linestyle 1 linecolor rgbcolor 'orange' linetype 1"
        x, y = data_create(timeset)
        plot.data << Gnuplot::DataSet.new([x, y]) do |ds|
          ds.with      = 'linespoints' # 点のみなら "points"
          ds.linecolor = 3
          ds.notitle
        end
        puts "#{ip} のグラフ生成完了"
      end
    end
  end
end

def print_all(timeset, path, range)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      puts 'すべてのグラフ生成開始'
      plot.title '全ノードのサービスレスポンスタイムの平均推移'
      plot.xlabel '経過時間(s)'
      plot.xrange "[#{range[:x_min].to_i - 5}:#{range[:x_max].to_i + 5}]"
      plot.ylabel 'サービスレスポンスタイム(ms)'
      plot.yrange "[#{range[:y_min].to_i - 5}:#{range[:y_max].to_i + 5}]"
      plot.set 'size 1,1'
      plot.set 'key right bottom'
      plot.terminal "png enhanced font 'IPA P ゴシック' fontscale 1.2"
      plot.output "#{path}/all.png"
      # plot.set "linestyle 1 linecolor rgbcolor 'orange' linetype 1"
      x, y = data_create(timeset)
      # plot.xrange   "[#{x_min - 1}:#{x_max+1}]"
      # plot.yrange   "[#{y_min - 1}:#{y_min+1}]"
      plot.data << Gnuplot::DataSet.new([x, y]) do |ds|
        ds.with = 'linespoints' # 点のみなら "points"
        ds.linecolor = 3
        ds.notitle
      end
      puts 'すべてのグラフ生成完了'
    end
  end
end

def exec_print(hash, path)
  directory_conf(path)
  ip_summary = create_ip_summary(hash)
  summary = create_summary(ip_summary)
  range = search_range(ip_summary)
  print_each_ip(ip_summary, path, range)
  print_all(summary, path, range)
end

def prepare_print(percent)
  log_path = '201904162'
  cat_all(percent, log_path)
  filename = "#{log_path}/log-#{percent}-all.txt"
  create_hash(filename)
end

6.times do |i|
  per = i * 20
  puts "#{per}percent result printing start"
  hash = prepare_print(per.to_s)
  # hash = create_hash('041020.log')
  exec_print(hash, "./resources/20190416-#{per}per")
  # exec_print(hash, './resources/041020')
end
