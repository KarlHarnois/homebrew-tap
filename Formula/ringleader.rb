class Ringleader < Formula
  desc "Tmux session manager for AI coding agents"
  homepage "https://github.com/KarlHarnois/ringleader"
  url "https://github.com/KarlHarnois/ringleader/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "864574c1aebce870437e62203de00365d72de6ef076acfc99481e044a35f57a4"
  license "MIT"

  bottle do
    root_url "https://github.com/KarlHarnois/homebrew-tap/releases/download/ringleader-0.2.1"
    sha256 arm64_sequoia: "0d36d6ec00ed08f255bce10e74301d6273d09f145b5ec7e789cad130094997bc"
  end

  PINNED_TOOLS = {
    "RINGLEADER_TMUX" => "tmux",
    "RINGLEADER_GIT"  => "git",
  }.freeze

  GIT_BUILD_OPTIONS = %w[
    NO_PERL=1
    NO_PYTHON=1
    NO_TCLTK=1
    NO_GETTEXT=1
    NO_INSTALL_HARDLINKS=1
  ].freeze

  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on "libevent"
  depends_on :macos
  depends_on "ncurses"
  depends_on "utf8proc"

  uses_from_macos "bison" => :build
  uses_from_macos "curl"
  uses_from_macos "expat"
  uses_from_macos "zlib"

  resource "tmux" do
    url "https://github.com/tmux/tmux/releases/download/3.6a/tmux-3.6a.tar.gz"
    sha256 "b6d8d9c76585db8ef5fa00d4931902fa4b8cbe8166f528f44fc403961a3f3759"

    patch do
      url "https://github.com/tmux/tmux/commit/e5a2a25fafb8ee107c230d8acad694f6b635f8bb.patch?full_index=1"
      sha256 "94afb2158801d1836ea011efa6d0c6bc55ff588394f46c5aa9a94aa515348efe"
    end
  end

  resource "git" do
    url "https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.54.0.tar.xz"
    sha256 "f689162364c10de79ef89aa8dbf48731eb057e34edbbd20aca510ce0154681a3"
  end

  def install
    install_tmux
    install_git
    install_ringleader
  end

  def install_tmux
    resource("tmux").stage do
      system "./configure", "--enable-utf8proc", *std_configure_args(prefix: libexec/"tmux")
      system "make", "install"
    end
  end

  def install_git
    resource("git").stage do
      system "make", "install", "prefix=#{libexec}/git", "CC=#{ENV.cc}", *GIT_BUILD_OPTIONS
      install_keychain_helper
    end
    (libexec/"git/etc/gitconfig").write <<~EOS
      [credential]
      \thelper = osxkeychain
    EOS
  end

  def install_keychain_helper
    cd "contrib/credential/osxkeychain" do
      system "make", "CC=#{ENV.cc}", "CFLAGS=#{ENV.cflags}", "LDFLAGS=#{ENV.ldflags}"
      (libexec/"git/libexec/git-core").install "git-credential-osxkeychain"
    end
  end

  def install_ringleader
    stamp_release_version
    system "cargo", "install", *std_cargo_args(root: libexec)
    (bin/"ringleader").write_env_script opt_libexec/"bin/ringleader", pinned_tool_defaults
  end

  def stamp_release_version
    inreplace "Cargo.toml", /^version = "[^"]+"$/, "version = \"#{version}\""
    inreplace "Cargo.lock", /^(name = "ringleader"\nversion = )"[^"]+"$/, "\\1\"#{version}\""
  end

  # The finder key binding records these paths, so they go through opt_libexec to survive `brew upgrade`.
  def pinned_tool_defaults
    PINNED_TOOLS.to_h do |variable, tool|
      [variable, "${#{variable}-#{opt_libexec}/#{tool}/bin/#{tool}}"]
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ringleader --version")

    doctor = shell_output("#{bin}/ringleader doctor 2>&1 || true")
    PINNED_TOOLS.each_value do |tool|
      assert_match "#{tool} program: #{opt_libexec}/#{tool}/bin/#{tool}", doctor
    end
    assert_match "tmux client #{resource("tmux").version}", doctor
    assert_match "git #{resource("git").version}", doctor
  end
end
