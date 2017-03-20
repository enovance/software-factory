%global         sum The Software Factory project

Name:           software-factory
Version:        2.5.0
Release:        1%{?dist}
Summary:        %{sum}

License:        ASL 2.0
URL:            https://softwarefactory-project.io/r/p/%{name}
Source0:        https://github.com/redhat-cip/software-factory/archive/%{version}.tar.gz

BuildArch:      noarch

%description
%{sum}

%package doc
Summary:        Software Factory documentation

BuildRequires:  python-sphinx

Requires:       managesf-doc
Requires:       python-sfmanager-doc

%description doc
Software Factory documentation


%prep
%autosetup -n %{name}-%{version}

%build
sphinx-build -b html -d build/doctrees docs/ build/html


%install
mkdir -p %{buildroot}/usr/share/doc/software-factory
mv build/html/* %{buildroot}/usr/share/doc/software-factory


%files
%license LICENSE

%files doc
/usr/share/doc/software-factory

%changelog
* Mon Mar 20 2017 Tristan Cacqueray <tdecacqu@redhat.com> - 2.5.0-1
- Initial packaging with only documentation
