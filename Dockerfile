FROM ubuntu:24.04 AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        autoconf automake bison bsdextrautils bzip2 ca-certificates curl flex gcc git groff \
        libc6-dev libcrypt-dev libfl-dev libncurses-dev libsqlite3-dev locales \
        make ncurses-term patch sqlite3 && \
    rm -rf /var/lib/apt/lists/*

RUN localedef -i ja_JP -f UTF-8 ja_JP.UTF-8 && \
    localedef -i ja_JP -f EUC-JP ja_JP.eucJP

WORKDIR /build

COPY dgamelaunch-ssh.patch /build/

RUN git init dgamelaunch && \
    cd dgamelaunch && \
    git fetch --depth 1 https://github.com/paxed/dgamelaunch.git 55bd7dce01db17356b05da966595ff1ae6097e60 && \
    git checkout --detach FETCH_HEAD && \
    patch -p1 < ../dgamelaunch-ssh.patch && \
    sed -i 's/-lrt/-lrt -pthread/' configure.ac && \
    sed -i \
        -e '/^maxnicklen/s/=.*/= 16/' \
        -e '/SERVERID/s/nethack\.alt\.org - http:\/\/nethack\.alt\.org\//JNetHack Server/' \
        -e '/^locale/s/en_US/ja_JP/' \
        -e '/^  game_\(path\|args\)/s/nethack/jnethack/' \
        -e '/^  game_name/s/NetHack 3\.4\.3/JNetHack 3.4.3-0.11/' \
        examples/dgamelaunch.conf && \
    sed -i 's/NetHack 3\.4\.3/JNetHack 3.4.3-0.11/' examples/dgl_menu_main_user.txt && \
    ./autogen.sh --enable-sqlite --enable-shmem \
        --with-config-file=/opt/nethack/nethack.alt.org/etc/dgamelaunch.conf && \
    make && \
    ./dgl-create-chroot && \
    install -D -m 0755 dgamelaunch /usr/local/libexec/dgamelaunch && \
    rm /opt/nethack/nethack.alt.org/dgamelaunch /opt/nethack/nethack.alt.org/dgamelaunch.[0-9]*

RUN curl -fsSL --retry 3 -O https://distfiles.macports.org/jnethack/nethack-343-src.tgz && \
    curl -fsSL --retry 3 -O https://distfiles.macports.org/jnethack/jnethack-3.4.3-0.11.diff.gz && \
    curl -fsSL --retry 3 -O https://elbereth.up.seesaa.net/nethack/jnethack-3.4.3-0.10-utf8-2.patch.bz2 && \
    printf '%s\n' \
        'bb39c3d2a9ee2df4a0c8fdde708fbc63740853a7608d2f4c560b488124866fe4  nethack-343-src.tgz' \
        'fbc071f6b33c53d89e8f13319ced952e605499a21d2086077296c631caff7389  jnethack-3.4.3-0.11.diff.gz' \
        '677411d906de6ec01b9e747384949e987a049d11b5c18e9df42587c2224b5b41  jnethack-3.4.3-0.10-utf8-2.patch.bz2' \
        | sha256sum -c - && \
    tar zxf nethack-343-src.tgz && \
    cd nethack-3.4.3 && \
    gzip -dc ../jnethack-3.4.3-0.11.diff.gz | patch -p1 && \
    bzip2 -dc ../jnethack-3.4.3-0.10-utf8-2.patch.bz2 | patch -p1 && \
    sh sys/unix/setup.sh x && \
    sed -i '/^CFLAGS/s/-O/-O2 -fcommon -fomit-frame-pointer/' \
        sys/unix/Makefile.src sys/unix/Makefile.utl && \
    sed -i \
        -e '/rmdir \.\/-p/d' \
        -e '/^PREFIX/s:=.*:= /opt/nethack/nethack.alt.org:' \
        -e '/^GAMEDIR/s:=.*:= $(PREFIX)/nh343:' \
        -e '/^VARDIR/s:=.*:= $(GAMEDIR)/var:' \
        -e '/^GAMEGRP/s:=.*:= games:' \
        sys/unix/Makefile.top && \
    sed -i \
        -e '/# define XI18N/d' \
        -e '/define HACKDIR/s:".*":"/nh343":' \
        -e '/define COMPRESS /s:".*":"/bin/gzip":' \
        include/config.h && \
    sed -i '/XI18N/i #include <locale.h>' sys/unix/unixmain.c && \
    sed -i \
        -e 's:/\* \(#define\s*\(SYSV\|LINUX\|TERMINFO\|TIMED_DELAY\)\s*\)\*/:\1:' \
        -e 's:/\* \(#define VAR_PLAYGROUND\).*:\1 "/nh343/var":' \
        include/unixconf.h && \
    sed -i '/^enter_explore_mode()/a {return 0;}\nSTATIC_PTR int _enter_explore_mode()' src/cmd.c && \
    sed -i \
        -e '/^#define ENTRYMAX/s/100/10000/' \
        -e '/^#define NAMSZ/s/10/16/' \
        -e '/^#define PERS_IS_UID/d' \
        src/topten.c && \
    make all && make install

RUN jail=/opt/nethack/nethack.alt.org && \
    cp -L --parents /bin/sh /usr/lib/locale/locale-archive "$jail" && \
    cp -a --parents "/usr/lib/$(gcc -print-multiarch)/gconv" "$jail" && \
    ldd "$jail/nh343/jnethack" | awk '$2 == "=>" && $3 ~ /^\// {print $3}' | \
        xargs -r cp -L --parents -t "$jail" && \
    chown -R root:root "$jail/nh343" && \
    chmod -R go-w "$jail/nh343" && \
    chmod 0755 "$jail/nh343/jnethack" && \
    chown -R games:games "$jail/nh343/var"

FROM ubuntu:24.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libcrypt1 libncursesw6 libsqlite3-0 openssh-server sudo && \
    rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub && \
    rm -rf /var/lib/apt/lists/* && \
    install -d -m 0755 /var/empty/nethack && \
    useradd --system --no-create-home --home-dir /var/empty/nethack --shell /bin/sh nethack && \
    passwd -d nethack

COPY --from=build /opt/nethack/nethack.alt.org /opt/nethack/nethack.alt.org
COPY --from=build /usr/local/libexec/dgamelaunch /usr/local/libexec/dgamelaunch
COPY --from=build /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive
COPY --chmod=0755 jnethack-session.sh /usr/local/libexec/jnethack-session
COPY --chmod=0755 start-sshd.sh /usr/local/sbin/start-sshd
COPY sshd_config /etc/ssh/sshd_config.jnethack
COPY --chmod=0440 dgamelaunch.sudoers /etc/sudoers.d/jnethack
RUN visudo -cf /etc/sudoers.d/jnethack

VOLUME ["/opt/nethack/nethack.alt.org/nh343/var", "/opt/nethack/nethack.alt.org/dgldir", "/var/lib/jnethack/ssh"]

EXPOSE 22

CMD ["/usr/local/sbin/start-sshd"]
