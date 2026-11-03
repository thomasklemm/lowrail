# shared job list: case base cand-list modes
W=/home/user/workspace/rails-wt
JOBS="iw_3|open-iw open-iw-s|i40 y40 i41 z41
iw_8|open-iw open-iw-s|i40 y40 i41 z41
iw_50|open-iw open-iw-s|i40 y40 i41 z41
iw_default_6|open-iw open-iw-s|i40 y40 i41 z41
serializable_hash|open-iw open-iw-s|i40 y40 i41 z41
ob_unsafe|open-ob|i40 y40 z41
ob_unsafe_plain|open-ob|i40 y40 z41
ob_safe|open-ob|i40 y40 z41
ob_render|open-ob|i40 y40 z41
preload_hm|open-pre open-pre-s|i40 y40 z41
preload_hmt|open-pre open-pre-s|i40 y40 z41
scope_hm|open-alias|i40 y40 z41
scope_hmt|open-alias|i40 y40 z41"
modeenv() { case $1 in
  i40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; F="" ;;
  y40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; F="--yjit" ;;
  i41) P=/home/user/workspace/ruby-src/install-9aa/bin; F="" ;;
  z41) P=/home/user/workspace/ruby-src/install-9aa/bin; F="--zjit" ;;
esac; }
export BUNDLE_ONLY=default:test:rubocop:cable:db
