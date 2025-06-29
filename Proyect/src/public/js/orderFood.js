export function initOrderFoodPage() {
  // Búsqueda y filtro por categoría
  const inputBusqueda = document.getElementById('buscador-comida');
  const productos = document.querySelectorAll('.producto-item');
  const categorias = document.querySelectorAll('.category-item');

  let categoriaSeleccionada = null;

  function filtrar() {
    const texto = inputBusqueda.value.toLowerCase().trim();

    productos.forEach(prod => {
      const nombre = prod.dataset.nombre;
      const categoria = prod.dataset.categoria;
      const coincideTexto = nombre.includes(texto);
      const coincideCategoria = !categoriaSeleccionada || categoria === categoriaSeleccionada;

      prod.style.display = (coincideTexto && coincideCategoria) ? 'block' : 'none';
    });
  }

  if (inputBusqueda) {
    inputBusqueda.addEventListener('input', filtrar);
  }

  if (categorias) {
    categorias.forEach(cat => {
      cat.addEventListener('click', () => {
        categorias.forEach(c => c.classList.remove('active'));
        cat.classList.add('active');

        categoriaSeleccionada = cat.dataset.id;
        filtrar();
      });
    });
  }

  // Carrito de compras
  let carrito = JSON.parse(localStorage.getItem('carrito')) || [];

  const listaCarrito = document.getElementById('lista-carrito');
  const totalCarrito = document.getElementById('total-carrito');
  const cantidadCarrito = document.getElementById('cantidad-carrito');

  function guardarCarrito() {
    localStorage.setItem('carrito', JSON.stringify(carrito));
  }

  function actualizarCarrito() {
    if (!listaCarrito || !totalCarrito || !cantidadCarrito) return;

    listaCarrito.innerHTML = '';
    let total = 0;
    let totalCantidad = 0;

    carrito.forEach((item, index) => {
      const li = document.createElement('li');
      li.classList.add('list-group-item', 'd-flex', 'justify-content-between', 'align-items-center');

      li.innerHTML = `
        ${item.nombre} x ${item.cantidad} - S/ ${(item.precio * item.cantidad).toFixed(2)}
        <button class="btn btn-danger btn-sm eliminar-item" data-index="${index}">Eliminar</button>
      `;

      listaCarrito.appendChild(li);
      total += item.precio * item.cantidad;
      totalCantidad += item.cantidad;
    });

    totalCarrito.textContent = total.toFixed(2);
    cantidadCarrito.textContent = totalCantidad;
    guardarCarrito();

    // Añadir event listener para eliminar productos
    document.querySelectorAll('.eliminar-item').forEach(btn => {
      btn.addEventListener('click', e => {
        const idx = e.target.dataset.index;
        carrito.splice(idx, 1);
        actualizarCarrito();
      });
    });
  }

  actualizarCarrito();

  // Evento para agregar productos al carrito
  document.querySelectorAll('.agregar-carrito').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.id;
      const nombre = btn.dataset.nombre;
      const precio = parseFloat(btn.dataset.precio);
      const cantidadInput = btn.parentElement.querySelector('.cantidad-input');
      const cantidad = parseInt(cantidadInput.value);

      if (cantidad > 0) {
        const existente = carrito.find(p => p.id === id);
        if (existente) {
          existente.cantidad += cantidad;
        } else {
          carrito.push({ id, nombre, precio, cantidad });
        }
        actualizarCarrito();
        cantidadInput.value = 1;
      }
    });
  });
}
