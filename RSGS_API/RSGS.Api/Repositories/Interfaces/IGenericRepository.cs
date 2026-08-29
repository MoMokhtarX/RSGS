using System.Linq.Expressions;

namespace RSGS.Api.Repositories.Interfaces;

public interface IGenericRepository<T> where T : class
{
    Task<List<T>> GetAllAsync();

    Task<T?> GetByIdAsync(int id);

    Task<T> AddAsync(T entity);

    Task UpdateAsync(T entity);

    Task DeleteAsync(T entity);

    Task<bool> ExistsAsync(Expression<Func<T, bool>> predicate);

    IQueryable<T> Query();
}