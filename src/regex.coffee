module.exports =
  # According to RCF 2812 (http://tools.ietf.org/html/rfc2812#section-2.3.1)
  # nickname = ( letter / special ) *8( letter / digit / special / "-" )
  # special  = "[", "]", "\", "`", "_", "^", "{", "|", "}"
  highlight: ///
    ^ # starts with
    (
      [a-zA-Z\[\]\\`_^\{|\}]     # letter / special
      [a-zA-Z0-9\[\]\\`_^\{|\}-] # letter / digit / special / '-'
        {1,15}                   # total length of 2 through 16
    )        # capture username
    [:;,]\s? # followed by ':', ';' or ',' (and optional whitespace)
  ///
  command: ///
    ^. # starts with any symbol (the command prefix)
    (.+?)\b # followed by the command (non-greedy match)
    \s?
  ///i
