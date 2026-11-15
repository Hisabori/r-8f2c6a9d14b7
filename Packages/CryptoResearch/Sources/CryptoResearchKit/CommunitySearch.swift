import Foundation
struct CommunitySearchHit {
 let post: CommunityPost
 let score: Int
 let reasons: [String]
}
struct CommunitySearchResults {
 let hits: [CommunitySearchHit]
 let duplicates: Int
}
enum CommunitySearch {
 static let aliases = [
  ["btc","bitcoin","비트코인"],["eth","ethereum","이더리움"],["xrp","리플"],
  ["sol","solana","솔라나"],["doge","dogecoin","도지코인"],["ada","cardano","에이다"],
  ["aapl","apple","애플"],["nvda","nvidia","엔비디아"],["tsla","tesla","테슬라"]
 ]
 struct Term {
  let raw: String
  let variants: [String]
  let excluded: Bool
 }
 static func normalize(_ value: String) -> String {
  value.precomposedStringWithCompatibilityMapping.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
 }
 static func has(_ title: String, _ term: String) -> Bool {
  if term.range(of: "^[a-z0-9.]+$",options:.regularExpression) != nil {
   return title.range(of:"(?<![a-z0-9])"+NSRegularExpression.escapedPattern(for:term)+"(?![a-z0-9])",options:.regularExpression) != nil
  }
  return title.contains(term)
 }
 static func parse(_ query: String) throws -> [Term] {
  guard query.count <= 120 else { throw StrategyError.invalid("검색어는 120자 이하로 입력하세요.") }
  let words = normalize(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
  guard words.count <= 8 else { throw StrategyError.invalid("검색어는 최대 8개 단어를 지원합니다.") }
  var seen = Set<String>()
  return try words.compactMap { word in
   let excluded = word.hasPrefix("-")
   let raw = String(excluded ? word.dropFirst() : word[...]).trimmingCharacters(in:CharacterSet(charactersIn:"#$"))
   guard !raw.isEmpty else { throw StrategyError.invalid("제외할 단어를 - 뒤에 입력하세요.") }
   let variants = aliases.first { $0.contains(raw) } ?? [raw]
   guard seen.insert((excluded ? "-" : "+")+variants[0]).inserted else { return nil }
   return Term(raw:raw,variants:variants,excluded:excluded)
  }
 }
 static func duplicateKey(_ value: String) -> String {
  var title = value
  for group in aliases {
   for alias in group {
    if alias.range(of:"^[a-z0-9.]+$",options:.regularExpression) != nil {
     title = title.replacingOccurrences(of:"(?<![a-z0-9])"+NSRegularExpression.escapedPattern(for:alias)+"(?![a-z0-9])",with:group[0],options:.regularExpression)
    } else { title = title.replacingOccurrences(of:alias,with:group[0]) }
   }
  }
  return title.replacingOccurrences(of:"[^\\p{L}\\p{N}]",with:"",options:.regularExpression)
 }
 static func run(_ posts: [CommunityPost], query: String, source: String, relevant: Bool, now: Int64) throws -> CommunitySearchResults {
  let terms = try parse(query)
  var candidates: [CommunitySearchHit] = []
  for post in posts.prefix(1000) {
   guard post.published_ms <= now, post.published_ms >= now-7*24*3600000,
         source == "전체" || post.source.lowercased() == source.lowercased() else { continue }
   let title = normalize(post.title)
   if terms.contains(where: { $0.excluded && $0.variants.contains(where: { has(title,$0) }) }) { continue }
   var reasons: [String] = []
   var score = 0
   var matches = true
   for term in terms where !term.excluded {
    guard let alias = term.variants.first(where: { has(title,$0) }) else { matches = false; break }
    score += alias == term.raw ? 6 : 4
    reasons.append(alias == term.raw ? term.raw : term.raw+" → "+alias)
   }
   guard matches else { continue }
   if !reasons.isEmpty { score += now-post.published_ms < 6*3600000 ? 2 : now-post.published_ms < 24*3600000 ? 1 : 0 }
   candidates.append(CommunitySearchHit(post:post,score:score,reasons:reasons))
  }
  candidates.sort {
   if relevant && $0.score != $1.score { return $0.score > $1.score }
   if $0.post.published_ms != $1.post.published_ms { return $0.post.published_ms > $1.post.published_ms }
   if $0.post.source != $1.post.source { return $0.post.source < $1.post.source }
   return $0.post.id < $1.post.id
  }
  var seen = Set<String>(), duplicates = 0
  let hits = candidates.filter {
   if seen.insert(duplicateKey(normalize($0.post.title))).inserted { return true }
   duplicates += 1;return false
  }
  return CommunitySearchResults(hits:hits,duplicates:duplicates)
 }
}
