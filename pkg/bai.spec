%global debug_package %{nil}

Name:           bai
Version:        0.4.4
Release:        1%{?dist}
Summary:        Translate natural-language shell requests into proposed commands

License:        MIT
URL:            https://github.com/trans/bai
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  brotli-devel
BuildRequires:  crystal
BuildRequires:  gc-devel
BuildRequires:  gcc
BuildRequires:  libzstd-devel
BuildRequires:  openssl-devel
BuildRequires:  pcre2-devel
BuildRequires:  redhat-rpm-config
BuildRequires:  zlib-devel

%description
bai is a small CLI that translates natural-language shell requests into
proposed commands. It prints the generated command to stdout and leaves
execution to the user.

%prep
%autosetup

%build
mkdir -p bin
crystal build --release --no-debug src/main.cr -o bin/bai

%install
install -Dpm0755 bin/bai %{buildroot}%{_bindir}/bai
install -Dpm0644 README.md %{buildroot}%{_docdir}/%{name}/README.md
install -Dpm0644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE

%files
%license %{_licensedir}/%{name}/LICENSE
%doc %{_docdir}/%{name}/README.md
%{_bindir}/bai

%changelog
* Fri Jun 26 2026 Thomas Sawyer <transfire@gmail.com> - 0.4.4-1
- Add local OpenAI-compatible chat provider support
- Generalize provider configuration with BAI_API_TYPE, BAI_BASE_URL, BAI_API_KEY, and BAI_MODEL
- Reject deprecated provider-specific model/base settings with migration errors

* Thu May 28 2026 Thomas Sawyer <transfire@gmail.com> - 0.4.3-1
- Loosen RPM runtime dependencies for openSUSE compatibility
- Reduce landing page rendering cost

* Thu May 28 2026 Thomas Sawyer <transfire@gmail.com> - 0.4.2-1
- Fedora packaging and CI validation fixes

* Wed May 27 2026 Thomas Sawyer <transfire@gmail.com> - 0.4.1-1
- Initial Fedora RPM packaging
