# frozen_string_literal: false

# User agent mixes for AB1's review: one browser, 20 common clients, and a long tail
# (in-app browsers, crawlers and scripts whose strings carry build numbers or names).
module AB1UAs
  TOP20 = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:144.0) Gecko/20100101 Firefox/144.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36 Edg/142.0.0.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 OPR/125.0.0.0",
    "Mozilla/5.0 (Linux; Android 15; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/28.0 Chrome/130.0.0.0 Mobile Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/142.0.7444.77 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.7444.59 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/116.0.1938.76 Safari/537.36",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36",
  ].freeze

  def self.tail(i)
    case i % 5
    when 0
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/22G100 [FBAN/FBIOS;FBAV/#{500 + i % 50}.0.0.#{i % 61}.#{i % 97};FBBV/#{700_000_000 + i};FBDV/iPhone16,2;FBMD/iPhone;FBSN/iOS;FBSV/18.6.2;FBSS/3;FBCR/;FBID/phone;FBLC/de_DE;FBOP/80]"
    when 1
      "Mozilla/5.0 (Linux; Android 14; SM-A546B Build/UP1A.231005.007; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/141.0.#{7000 + i % 400}.#{i % 200} Mobile Safari/537.36 Instagram 389.0.0.#{i % 50}.#{i % 100} Android (34/14; 450dpi; 1080x2340; samsung; SM-A546B; a54x; s5e8835; de_DE; #{700_000_000 + i})"
    when 2
      "Mozilla/5.0 (compatible; Crawler#{i}/1.#{i % 10}; +https://crawler#{i}.example.com/bot)"
    when 3
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.#{i} Safari/537.36"
    else
      "python-requests/2.#{i % 33}.#{i}"
    end
  end

  # name => [sequence of user agents, description]
  def self.mixes(length = 20_000)
    rng = Random.new(42)
    pool = TOP20 + (0...4_980).map { |i| tail(i) }
    # Zipf(1) weights over 5,000 distinct user agents.
    cumulative = []
    sum = 0.0
    pool.each_index { |k| sum += 1.0 / (k + 1); cumulative << sum }
    zipf = Array.new(length) { pool[cumulative.bsearch_index { |c| c >= rng.rand * sum }] }
    {
      "one" => Array.new(length) { TOP20[1] },
      "top20" => Array.new(length) { |i| TOP20[i % 20] },
      "top20+20%unique" => Array.new(length) { |i| i % 5 == 4 ? tail(10_000 + i) : TOP20[rng.rand(20)] },
      "zipf5000" => zipf,
      "unique" => Array.new(length) { |i| tail(10_000 + i) },
    }
  end
end
