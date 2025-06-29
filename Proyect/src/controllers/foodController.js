import conexion from '../database/db.js';

export const getFoodCategoriesAndProducts = async (req, res) => {
  try {
    const [categoriasResult] = await conexion.execute('CALL listarCategoriasComida()');
    const [productosResult] = await conexion.execute('CALL ListarProductosActivos()');

    const categorias = categoriasResult[0];
    const productos = productosResult[0];

    res.render('order-food', {
      title: 'Casa Andina',
      layout: 'layouts/main',
      categorias,
      productos
    });
  } catch (error) {
    console.error('Error al obtener categorías o productos:', error);
    res.status(500).send('Error del servidor');
  }
};
