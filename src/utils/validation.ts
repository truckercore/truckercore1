export const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

export const validatePhone = (phone: string): boolean => {
  const phoneRegex = /^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/;
  return phoneRegex.test(phone);
};

export const validateZipCode = (zip: string): boolean => {
  const zipRegex = /^\d{5}(-\d{4})?$/;
  return zipRegex.test(zip);
};

export const validateLoadNumber = (loadNumber: string): boolean => {
  const loadRegex = /^LD-\d{4}-\d{3,6}$/;
  return loadRegex.test(loadNumber);
};

export const validateWeight = (weight: number): boolean => {
  return weight > 0 && weight <= 80000; // Max legal weight
};

export const validateDate = (date: string): boolean => {
  const dateObj = new Date(date);
  return dateObj instanceof Date && !isNaN(dateObj.getTime());
};

export const isDateInFuture = (date: string): boolean => {
  return new Date(date) > new Date();
};

export const isDateBeforeDelivery = (pickupDate: string, deliveryDate: string): boolean => {
  return new Date(pickupDate) < new Date(deliveryDate);
};
