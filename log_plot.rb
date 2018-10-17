hash = {}
filename = "あり"
begin
  File.open("./resources/" + filename + ".log") do |file|
    file.each_line do |l|
      ip = l.match(/(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/)
      time =  l.match(/([0-9]*).0ns/)[1]
      second = l.match(/([0-9]*).0ns\Z/)[1]
      if(hash[ip.to_s] == nil)
        hash[ip.to_s] = Hash.new
      end
      hash[ip.to_s][time.to_s] = second.to_s
    end
  end

# 例外は小さい単位で捕捉する
rescue SystemCallError => e
  puts %Q(class=[#{e.class}] message=[#{e.message}])
rescue IOError => e
  puts %Q(class=[#{e.class}] message=[#{e.message}])
end
require "gnuplot"
hash.each do |ip, timeset|
  Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "Delay of #{ip} seen from the server node"
      plot.xlabel 'time(s)'
      plot.xrange   "[-1:21]"
      plot.ylabel 'delay(ms)'
      plot.yrange   "[0:11]"
      plot.set "size 1,1"
      plot.terminal "png enhanced font 'IPA P ゴシック' fontscale 1.2"
      plot.output "./resources/#{filename}/#{ip}.png"
      # plot.set "linestyle 1 linecolor rgbcolor 'orange' linetype 1"

      x = []
      y = []
      timeset.each do |time, second|
        x.push (time.to_f / 1000000000)
        y.push (second.to_f / 1000000)
        # puts x.last.to_s + ":" + y.last.to_s
      end
      new_x = []
      new_y = []
      plot.data << Gnuplot::DataSet.new([x,y]) do |ds|
        ds.with      = "linespoints"  # 点のみなら "points"
        ds.linecolor = 3
        ds.notitle
      end
    end
  end
end

Gnuplot.open do |gp|
    Gnuplot::Plot.new(gp) do |plot|
      plot.title "Delay seen from the server node"
      plot.xlabel 'time(s)'
      plot.xrange   "[-1:21]"
      plot.ylabel 'delay(ms)'
      plot.yrange   "[0:11]"
      plot.set "size 1,1"
      plot.terminal "png enhanced font 'IPA P ゴシック' fontscale 1.2"
      plot.output "./resources/#{filename}/all.png"
      # plot.set "linestyle 1 linecolor rgbcolor 'orange' linetype 1"
      hash.each do |ip, timeset|
        x = []
        y = []
        timeset.each do |time, second|
          x.push (time.to_f / 1000000000)
          y.push (second.to_f / 1000000)
          # puts x.last.to_s + ":" + y.last.to_s
        end
        new_x = []
        new_y = []
        plot.data << Gnuplot::DataSet.new([x,y]) do |ds|
          ds.with      = "linespoints"  # 点のみなら "points"
          ds.title = "#{ip}"
        end
      end
    end
  end
