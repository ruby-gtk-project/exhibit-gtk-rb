{
  adwaita = {
    dependencies = ["gtk4" "rake"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qhyga8fv7xp28i3lwiz3ifg8w8srwyrk892nifbnj0fi87xczlc";
      type = "gem";
    };
    version = "4.3.6";
  };
  atk = {
    dependencies = ["glib2" "rake"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1yklm8rdvxl63mqyk8z74idvsqaj9i2i2flsm73px88bqx937jmh";
      type = "gem";
    };
    version = "4.3.6";
  };
  cairo = {
    dependencies = ["pkg-config" "red-colors"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08x6f2idyfnylq0b66mqi8lf5mjvff2y2q02n5hq0x4i3ha5cwz5";
      type = "gem";
    };
    version = "1.18.5";
  };
  cairo-gobject = {
    dependencies = ["cairo" "glib2"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hxblh0k3h2ar4y47lify1fwjskmisvac24v72xwgn3q7znvds36";
      type = "gem";
    };
    version = "4.3.6";
  };
  ffi = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1kqasqvy8d7r09ri4n6bkdwbk63j7afd9ilsw34nzlgh0qp69ldw";
      type = "gem";
    };
    version = "1.17.4";
  };
  fiddle = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vifygrkw22gcd4wzh8gc4pv6h1zpk6kll6mmprrf5174wvfxa3z";
      type = "gem";
    };
    version = "1.1.8";
  };
  gdk4 = {
    dependencies = ["cairo-gobject" "gdk_pixbuf2" "pango" "rake"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0kv1pqma8i3fqlyypdf8b73n41gs22h3ij92xhv274kaaj19pqfk";
      type = "gem";
    };
    version = "4.3.6";
  };
  gdk_pixbuf2 = {
    dependencies = ["gio2" "rake"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ihv48n5vq7xrxwspm2icx9rszgygkhkcg6w4lv0cygay695nmn2";
      type = "gem";
    };
    version = "4.3.6";
  };
  gio2 = {
    dependencies = ["fiddle" "gobject-introspection"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19fmvs919hnr5i9xwq9fw4vgnym3j37ngnbz1zfb8921c6qpvlsi";
      type = "gem";
    };
    version = "4.3.6";
  };
  glib2 = {
    dependencies = ["native-package-installer" "pkg-config"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1k71h37jv0hn61sw9nrmph6mlw1y2d4bibk43163ndj7v1vfq76j";
      type = "gem";
    };
    version = "4.3.6";
  };
  gobject-introspection = {
    dependencies = ["glib2"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0sw7fny16rhvdbbnk80vikl081jkbmmyg2r3b3i47hmyamjzc2bg";
      type = "gem";
    };
    version = "4.3.6";
  };
  graphene1 = {
    dependencies = ["gobject-introspection"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vjfgcabxx0rdnx4600b0bk7bbspbvam07gwl5f14ipccwxfbryj";
      type = "gem";
    };
    version = "4.3.6";
  };
  gsk4 = {
    dependencies = ["gdk4" "graphene1"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1q3a36jlb4l453h3bqpdy5vlwf5y4a3mxxd06i5p19hm23pcbbsi";
      type = "gem";
    };
    version = "4.3.6";
  };
  gtk4 = {
    dependencies = ["atk" "gdk4" "gsk4"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a86is058a286cybq0a5hc36k61jdwwiqdc9f85lfshx0znsg9rh";
      type = "gem";
    };
    version = "4.3.6";
  };
  json = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10q54a0dkm0050n0zzqiv2ln8w931wszybbhym1i8r4mbpvkv90k";
      type = "gem";
    };
    version = "2.21.1";
  };
  matrix = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nscas3a4mmrp1rc07cdjlbbpb2rydkindmbj3v3z5y1viyspmd0";
      type = "gem";
    };
    version = "0.4.3";
  };
  native-package-installer = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bvr9q7qwbmg9jfg85r1i5l7d0yxlgp0l2jg62j921vm49mipd7v";
      type = "gem";
    };
    version = "1.1.9";
  };
  pango = {
    dependencies = ["cairo-gobject" "gobject-introspection"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1p5ygivdz43ca96fap6k9ric7m72nm908cix2p0gl84blxav7sq4";
      type = "gem";
    };
    version = "4.3.6";
  };
  pkg-config = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cy75ssbwjzi9z3zwfx2zq3b8xvpy9rbdf1rnhi3v612acfgiy9k";
      type = "gem";
    };
    version = "1.6.5";
  };
  rake = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "009p524zl0p0kfa65nii8wdmaigkmawv9pbvlcffky7islmmp0nb";
      type = "gem";
    };
    version = "13.4.2";
  };
  red-colors = {
    dependencies = ["json" "matrix"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16lj0h6gzmc07xp5rhq5b7c1carajjzmyr27m96c99icg2hfnmi3";
      type = "gem";
    };
    version = "0.4.0";
  };
}
