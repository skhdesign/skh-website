const slides = [...document.querySelectorAll('.slide')];
const dots = [...document.querySelectorAll('.dot')];
const navbar = document.getElementById('navbar');
const btn = document.getElementById('menuToggle');
const nav = document.getElementById('navLinks');

let currentIndex = 0;
let timerId = null;
let isTransitioning = false;

const slideInterval = 8000;
const crossfadeDuration = 2400;

function normalizeIndex(index) {
  return slides.length ? (index + slides.length) % slides.length : 0;
}

function showSlide(index, immediate = false) {
  if (!slides.length) return;

  const nextIndex = normalizeIndex(index);

  if (!immediate && (nextIndex === currentIndex || isTransitioning)) return;
  if (!immediate) isTransitioning = true;

  slides.forEach((slide, slideIndex) => {
    const active = slideIndex === nextIndex;
    slide.classList.toggle('active', active);
    slide.setAttribute('aria-hidden', active ? 'false' : 'true');
  });

  dots.forEach((dot, dotIndex) => {
    const active = dotIndex === nextIndex;
    dot.classList.toggle('active', active);
    dot.setAttribute('aria-current', active ? 'true' : 'false');
  });

  currentIndex = nextIndex;

  if (!immediate) {
    window.setTimeout(() => {
      isTransitioning = false;
    }, crossfadeDuration + 100);
  }
}

function startSlider() {
  if (!slides.length) return;
  window.clearInterval(timerId);
  timerId = window.setInterval(() => {
    if (!isTransitioning) showSlide(currentIndex + 1);
  }, slideInterval);
}

dots.forEach((dot, index) => {
  dot.addEventListener('click', () => {
    if (index === currentIndex) return;
    showSlide(index);
    startSlider();
  });
});

if (navbar) {
  window.addEventListener('scroll', () => {
    navbar.classList.toggle('scrolled', window.scrollY > 40);
  });
}

function getSlideImageUrls() {
  return slides
    .map(slide => slide.querySelector('.slide-image'))
    .filter(Boolean)
    .map(image => image.style.backgroundImage
      .replace(/^url\(["']?/, '')
      .replace(/["']?\)$/, ''))
    .filter(Boolean);
}

function preloadImages(urls) {
  return Promise.all(
    urls.map(url => new Promise(resolve => {
      const image = new Image();
      image.onload = resolve;
      image.onerror = resolve;
      image.src = url;
    }))
  );
}

function runIntro() {
  const body = document.body;

  window.setTimeout(() => body.classList.add('show-brand'), 120);
  window.setTimeout(() => body.classList.add('show-nav'), 650);
  window.setTimeout(() => body.classList.add('show-hero'), 1050);
  window.setTimeout(() => body.classList.add('show-content'), 1750);

  window.setTimeout(() => {
    body.classList.add('intro-complete');
    body.classList.remove(
      'page-enter','show-brand','show-nav','show-hero',
      'show-content','images-loading'
    );
    startSlider();
  }, 2700);
}

async function preparePage() {
  if (!slides.length) {
    document.body.classList.remove('page-enter');
    document.body.classList.add('intro-complete');
    return;
  }

  document.body.classList.add('images-loading');
  showSlide(0, true);

  await Promise.race([
    preloadImages(getSlideImageUrls()),
    new Promise(resolve => window.setTimeout(resolve, 2500))
  ]);

  runIntro();
}

preparePage();

document.querySelectorAll('[data-detail-gallery]').forEach(g=>{const t=g.querySelector('.detail-track'),s=[...g.querySelectorAll('.detail-slide')],d=[...g.querySelectorAll('.detail-dot')],p=g.querySelector('.detail-prev'),n=g.querySelector('.detail-next');if(!t||!s.length)return;let i=0;const r=()=>{t.style.transform=`translateX(-${i*100}%)`;d.forEach((x,k)=>x.classList.toggle('active',k===i))};const go=x=>{i=(x+s.length)%s.length;r()};p&&p.addEventListener('click',()=>go(i-1));n&&n.addEventListener('click',()=>go(i+1));d.forEach((x,k)=>x.addEventListener('click',()=>go(k)));let st=null;t.addEventListener('pointerdown',e=>st=e.clientX);t.addEventListener('pointerup',e=>{if(st===null)return;const q=e.clientX-st;if(Math.abs(q)>50)go(i+(q<0?1:-1));st=null});r()});




/* =========================
   V7 智慧導覽列：下滑收起、上滑顯示
========================= */
(() => {
  const smartNav = document.querySelector('.detail-page .inner-navbar, .inner-page .inner-navbar');
  if (!smartNav) return;

  let lastScrollY = window.scrollY;
  let ticking = false;

  const updateNav = () => {
    const currentScrollY = window.scrollY;
    const difference = currentScrollY - lastScrollY;

    if (currentScrollY <= 20) {
      smartNav.classList.remove('nav-hidden');
    } else if (difference > 7) {
      smartNav.classList.add('nav-hidden');
    } else if (difference < -7) {
      smartNav.classList.remove('nav-hidden');
    }

    lastScrollY = currentScrollY;
    ticking = false;
  };

  window.addEventListener('scroll', () => {
    if (!ticking) {
      window.requestAnimationFrame(updateNav);
      ticking = true;
    }
  }, { passive:true });
})();



/* =========================
   V8 案件詳情頁：縮圖切換＋黑底 Lightbox
========================= */
document.querySelectorAll('[data-detail-gallery]').forEach(gallery => {
  const track = gallery.querySelector('.detail-track');
  const slides = [...gallery.querySelectorAll('.detail-slide')];
  const thumbs = [...gallery.querySelectorAll('.detail-thumb')];

  const lightbox = document.getElementById('lightbox');
  const lightboxImage = lightbox?.querySelector('.lightbox-image');
  const lightboxClose = lightbox?.querySelector('.lightbox-close');
  const lightboxLeft = lightbox?.querySelector('.lightbox-zone-left');
  const lightboxRight = lightbox?.querySelector('.lightbox-zone-right');
  const lightboxCounter = lightbox?.querySelector('.lightbox-counter');

  if (!track || !slides.length) return;

  const imageData = slides.map(slide => {
    const image = slide.querySelector('img');
    return {
      src: image?.getAttribute('src') || '',
      alt: image?.getAttribute('alt') || ''
    };
  });

  let index = 0;
  let lightboxIndex = 0;
  let dragStartX = null;

  const renderGallery = () => {
    track.style.transform = `translate3d(-${index * 100}%,0,0)`;

    thumbs.forEach((thumb, thumbIndex) => {
      const active = thumbIndex === index;
      thumb.classList.toggle('active', active);
      thumb.setAttribute('aria-current', active ? 'true' : 'false');
    });
  };

  const goGallery = newIndex => {
    index = (newIndex + slides.length) % slides.length;
    renderGallery();
  };

  thumbs.forEach((thumb, thumbIndex) => {
    thumb.addEventListener('click', () => goGallery(thumbIndex));
  });

  const renderLightbox = () => {
    if (!lightboxImage) return;

    lightboxImage.classList.remove('visible');

    window.setTimeout(() => {
      lightboxImage.src = imageData[lightboxIndex].src;
      lightboxImage.alt = imageData[lightboxIndex].alt;

      if (lightboxCounter) {
        lightboxCounter.textContent = `${lightboxIndex + 1} / ${imageData.length}`;
      }

      requestAnimationFrame(() => {
        lightboxImage.classList.add('visible');
      });
    }, 120);
  };

  const openLightbox = startIndex => {
    if (!lightbox) return;

    lightboxIndex = startIndex;
    renderLightbox();

    lightbox.classList.add('open');
    lightbox.setAttribute('aria-hidden', 'false');
    document.body.classList.add('lightbox-open');
  };

  const closeLightbox = () => {
    if (!lightbox) return;

    lightbox.classList.remove('open');
    lightbox.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('lightbox-open');
  };

  const goLightbox = newIndex => {
    lightboxIndex = (newIndex + imageData.length) % imageData.length;
    renderLightbox();
  };

  slides.forEach((slide, slideIndex) => {
    slide.addEventListener('click', () => openLightbox(slideIndex));
  });

  lightboxClose?.addEventListener('click', closeLightbox);
  lightboxLeft?.addEventListener('click', () => goLightbox(lightboxIndex - 1));
  lightboxRight?.addEventListener('click', () => goLightbox(lightboxIndex + 1));

  lightbox?.addEventListener('click', event => {
    if (event.target === lightbox) closeLightbox();
  });

  lightbox?.addEventListener('pointerdown', event => {
    dragStartX = event.clientX;
  });

  lightbox?.addEventListener('pointerup', event => {
    if (dragStartX === null) return;

    const distance = event.clientX - dragStartX;
    if (Math.abs(distance) > 55) {
      goLightbox(lightboxIndex + (distance < 0 ? 1 : -1));
    }

    dragStartX = null;
  });

  document.addEventListener('keydown', event => {
    if (!lightbox?.classList.contains('open')) return;

    if (event.key === 'Escape') closeLightbox();
    if (event.key === 'ArrowLeft') goLightbox(lightboxIndex - 1);
    if (event.key === 'ArrowRight') goLightbox(lightboxIndex + 1);
  });

  renderGallery();
});






/* =========================
   V15 內頁圖文進場動畫
========================= */
document.addEventListener('DOMContentLoaded', () => {
  const page = document.querySelector('.page-reveal');
  if (!page) return;

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      page.classList.add('ready');
    });
  });
});



// =========================
// V24 手機右側滑出選單（修正版）
// =========================
document.addEventListener("DOMContentLoaded", () => {
  const menuToggle = document.getElementById("menuToggle");
  const navLinks = document.getElementById("navLinks");
  const menuOverlay = document.getElementById("menuOverlay");

  if (!menuToggle || !navLinks || !menuOverlay) return;

  const closeMenu = () => {
    // 同時清除新版與舊版 class，避免 Safari 返回頁面時保留開啟狀態
    navLinks.classList.remove("is-open", "open");
    menuOverlay.classList.remove("is-open");
    menuToggle.classList.remove("is-open");
    document.body.classList.remove("menu-open");

    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "開啟選單");
    menuOverlay.setAttribute("aria-hidden", "true");
  };

  const openMenu = () => {
    navLinks.classList.remove("open");
    navLinks.classList.add("is-open");
    menuOverlay.classList.add("is-open");
    menuToggle.classList.add("is-open");
    document.body.classList.add("menu-open");

    menuToggle.setAttribute("aria-expanded", "true");
    menuToggle.setAttribute("aria-label", "關閉選單");
    menuOverlay.setAttribute("aria-hidden", "false");
  };

  // 每次載入或從 Safari 上一頁返回，都強制先關閉
  closeMenu();
  window.addEventListener("pageshow", closeMenu);

  menuToggle.addEventListener("click", (event) => {
    event.preventDefault();
    event.stopPropagation();

    if (navLinks.classList.contains("is-open")) {
      closeMenu();
    } else {
      openMenu();
    }
  });

  // 點擊選單以外的遮罩範圍即可收回
  menuOverlay.addEventListener("click", (event) => {
    event.preventDefault();
    closeMenu();
  });

  navLinks.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", closeMenu);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeMenu();
  });

  window.addEventListener("resize", () => {
    if (window.innerWidth > 900) closeMenu();
  });
});
